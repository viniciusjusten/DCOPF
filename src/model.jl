function linear_flow!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer
    
    # Ybus = inputs.Ybus
    # Gbus = real(Ybus)
    # Xbus = imag(Ybus.^(-1))
    # num_bus = size(Ybus)[1]
    
    # phase_reference = inputs.phase_reference
    # demand = inputs.demand
    # min_flow = inputs.min_flow
    # max_flow = inputs.max_flow
    # max_generation = inputs.max_generation
    # min_generation = inputs.min_generation

    num_generators = get_num_generators(inputs.generators)
    num_buses = get_num_buses(inputs.buses)
    num_branches = get_num_branches(inputs.branches)

    
    if !inputs.consider_losses
        power_loss = zeros(AffExpr, num_buses, num_buses)
        model.expr["PowerLoss"] = power_loss
    else
        if inputs.linearize_loss
            power_loss_var = variableref(num_buses, num_buses)
            power_loss = zeros(AffExpr, num_buses, num_buses)
            for bus_from in 1:num_buses, bus_to in 1:num_buses
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
        else
            power_loss = zeros(QuadExpr, num_buses, num_buses)
            model.expr["PowerLoss"] = power_loss
        end
    end
    
    ### create variables
    phase = variableref(num_buses)
    generation = variableref(num_generators)
    
    ### create constraints
    load_balance = constraintref(num_buses)
    flow_lower_bound = constraintref(num_branches)
    flow_upper_bound = constraintref(num_branches)
    
    ### create expressions
    flow = zeros(AffExpr, num_branches)
    power_injection = zeros(AffExpr, num_buses)
    generation_per_bus = zeros(AffExpr, num_buses)
    
    ### define variables
    for gen in 1:num_generators
        generation[gen] = @variable(
            optimizer_model,
            lower_bound = get_min_generation(inputs.generators, gen),
            upper_bound = get_max_generation(inputs.generators, gen),
        )
    end
    for bus in 1:num_buses
        for gen in generators_in_bus(inputs.generators, inputs.buses.id[bus])
            generation_per_bus[bus] = @expression(
                optimizer_model,
                generation_per_bus[bus] + generation[gen]
            )
        end
        phase[bus] = @variable(
            optimizer_model
        )
        # bus for angle reference
        if bus_is_reference(inputs.buses, bus)
            JuMP.fix(phase[bus], 0.0; force = true)
        end
    end
    # save variables
    model.var["Phase"] = phase
    model.var["Generation"] = generation
    model.expr["GenerationPerBus"] = generation_per_bus
    
    ### define expressions
    for branch in 1:num_branches
        bus_from = get_bus_idx_from_bus_id(inputs.buses, inputs.branches.bus_from[branch])
        bus_to = get_bus_idx_from_bus_id(inputs.buses, inputs.branches.bus_to[branch])
        flow[branch] = @expression(
            optimizer_model,
            (phase[bus_from] - phase[bus_to])/get_reactance(inputs.branches, branch)
        )
        power_injection[bus_from] = @expression(
            optimizer_model,
            power_injection[bus_from] + flow[branch]
        )
        power_injection[bus_to] = @expression(
            optimizer_model,
            power_injection[bus_to] - flow[branch]
        )
    end
    # save expressions
    model.expr["Flow"] = flow
    model.expr["PowerInjection"] = power_injection
    
    ### define constraints
    for bus in 1:num_buses
        load_balance[bus] = @constraint(
            optimizer_model,
            generation_per_bus[bus] == 
                get_bus_demand(inputs.buses, bus)
                + power_injection[bus] + sum(power_loss[bus, :])/2
        )
    end
    for branch in 1:num_branches
        flow_upper_bound[branch] = @constraint(
            optimizer_model,
            flow[branch] <= get_max_flow(inputs.branches, branch)
        )
        flow_lower_bound[branch] = @constraint(
            optimizer_model,
            flow[branch] >= -get_max_flow(inputs.branches, branch)
        )
    end
    if inputs.consider_losses
        if inputs.linearize_loss
            # creates epigraphs with power loss cuts
            loss_cuts!(model, inputs)
        else
            quadratic_loss!(model, inputs)
        end
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

function quadratic_loss!(model::DCOPFModel, inputs::DCOPFInputs)
    Ybus = inputs.Ybus
    num_bus = size(Ybus)[1]

    power_loss = model.expr["PowerLoss"]
    phase = model.var["Phase"]

    for bus_from in 1:num_bus, bus_to in 1:num_bus
        conductance = -real(Ybus)[bus_from, bus_to]
        power_loss[bus_from, bus_to] = @expression(
            model.optimizer,
            conductance * (phase[bus_from] - phase[bus_to])^2
        )
    end
end

function transmission_loss(phase_difference::Float64, conductance::Float64)
    return conductance * phase_difference^2
end

function transmission_loss_derivative(phase_difference::Float64, conductance::Float64)
    return 2 * conductance * phase_difference
end
