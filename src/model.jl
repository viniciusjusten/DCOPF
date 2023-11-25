function linear_flow!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer
    
    Ybus = inputs.Ybus
    Gbus = real(Ybus)
    Xbus = imag(Ybus.^(-1))
    num_bus = size(Ybus)[1]
    
    phase_reference = inputs.phase_reference
    demand = inputs.demand
    min_flow = inputs.min_flow
    max_flow = inputs.max_flow
    max_generation = inputs.max_generation
    min_generation = inputs.min_generation
    
    if !inputs.consider_losses
        power_loss = zeros(AffExpr, num_bus, num_bus)
        model.expr["PowerLoss"] = power_loss
    else
        power_loss_var = variableref(num_bus, num_bus)
        power_loss = zeros(AffExpr, num_bus, num_bus)
        for bus_from in 1:num_bus, bus_to in 1:num_bus
            if bus_from != bus_to
                power_loss_var[bus_from, bus_to] = @variable(
                    optimizer_model,
                    lower_bound = 0.0,
                )
                power_loss[bus_from, bus_to] = power_loss_var[bus_from, bus_to]
            end
        end
        model.var["PowerLossVar"] = power_loss_var
        model.expr["PowerLoss"] = power_loss
    end
    
    ### create variables
    phase = variableref(num_bus)
    generation = variableref(num_bus)
    
    ### create constraints
    load_balance = constraintref(num_bus)
    flow_lower_bound = constraintref(num_bus, num_bus)
    flow_upper_bound = constraintref(num_bus, num_bus)
    
    ### create expressionss
    flow = zeros(AffExpr, num_bus, num_bus)
    power_injection = expressionref(num_bus)
    
    ### define variables
    for bus in 1:num_bus
        generation[bus] = @variable(
            optimizer_model,
            lower_bound = min_generation[bus],
            upper_bound = max_generation[bus]
        )
        if bus == phase_reference
            phase[bus] = @variable(
                optimizer_model,
                lower_bound = 0,
                upper_bound = 0
            )
        else
            phase[bus] = @variable(
                optimizer_model
            )
        end
    end
    # save variables
    model.var["Phase"] = phase
    model.var["Generation"] = generation
    
    ### define expressions
    for bus_from in 1:num_bus, bus_to in 1:num_bus
        if bus_from == bus_to
            continue
        end
        flow[bus_from, bus_to] = @expression(
            optimizer_model,
            (phase[bus_from] - phase[bus_to])/Xbus[bus_from, bus_to]
        )
    end
    for bus in 1:num_bus
        power_injection[bus] = @expression(
            optimizer_model,
            sum(flow[bus, :])    
        )
    end
    # save expressions
    model.expr["Flow"] = flow
    model.expr["PowerInjection"] = power_injection
    
    ### define constraints
    for bus in 1:num_bus
        load_balance[bus] = @constraint(
            optimizer_model,
            generation[bus] == demand[bus] + power_injection[bus] + sum(power_loss[bus, :])/2
        )
    end
    for bus_from in 1:num_bus, bus_to in 1:num_bus
        flow_upper_bound[bus_from, bus_to] = @constraint(
            optimizer_model,
            flow[bus_from, bus_to] <= max_flow[bus_from, bus_to]
        )
        flow_lower_bound[bus_from, bus_to] = @constraint(
            optimizer_model,
            flow[bus_from, bus_to] >= min_flow[bus_from, bus_to]
        )
    end
    if inputs.consider_losses
        # creates epigraphs with power loss cuts
        loss_cuts!(model, inputs)
    end
    # save constraints
    model.con["LoadBalance"] = load_balance
    model.con["FlowLowerBound"] = flow_lower_bound
    model.con["FlowUpperBound"] = flow_upper_bound
    
end

function loss_cuts!(model::DCOPFModel, inputs::DCOPFInputs)
    Ybus = inputs.Ybus
    num_bus = size(Ybus)[1]
    phase = model.var["Phase"]
    for (k, group) in model.cuts
        if "PowerLoss" in k
            for bus_from in 1:num_bus, bus_to in 1:num_bus
                @constraint(
                    model.optimizer,
                    model.expr["PowerLoss"][bus_from, bus_to] >= 
                        [phase[bus_from] - phase[bus_to], 1]' * group[bus_from, bus_to]
                )
            end
        end
    end
end

function new_loss_cut!(
    model::DCOPFModel,
    inputs::DCOPFInputs,
    results::DCOPFResults,
    current_iteration::Int
)
    Ybus = inputs.Ybus
    num_bus = size(Ybus)[1]

    phase = results.var["Phase", current_iteration]
    loss_cut = Array{Vector{Float64}, 2}(undef, num_bus, num_bus)
    loss = zeros(num_bus, num_bus)

    for bus_from in 1:num_bus, bus_to in 1:num_bus
        phase_difference = phase[bus_from] - phase[bus_to]
        conductance = -real(Ybus)[bus_from, bus_to]
        loss_derivative = transmission_loss_derivative(phase_difference, conductance)
        loss[bus_from, bus_to] = transmission_loss(phase_difference, conductance)
        # cut is a vector [a, b] where y = a*x + b
        loss_cut[bus_from, bus_to] = [loss_derivative, loss[bus_from, bus_to] - (loss_derivative * phase_difference)]
    end

    if maximum(abs.(loss - results.expr["PowerLoss", current_iteration])) <= inputs.tolerance
        return :stop
    else
        model.cuts["PowerLoss", current_iteration] = loss_cut
        return nothing
    end
end

function transmission_loss(phase_difference::Float64, conductance::Float64)
    return conductance * phase_difference^2
end

function transmission_loss_derivative(phase_difference::Float64, conductance::Float64)
    return 2 * conductance * phase_difference
end
