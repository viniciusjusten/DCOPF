function phase!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer

    num_buses = get_num_buses(inputs.buses)

    ### create variables
    phase = variableref(num_buses)

    ### define variables
    # start variables
    start_phase = fill(nothing, (size(phase)))
    if inputs.consider_variable_initialization && inputs.initialize_variables["Iteration"] > 1
        start_phase = inputs.initialize_variables["Phase"]
    end

    for bus in 1:num_buses
        phase[bus] = @variable(
            optimizer_model,
            start = start_phase[bus],
        )
        # bus for angle reference
        if bus_is_reference(inputs.buses, bus)
            JuMP.fix(phase[bus], 0.0; force = true)
        end
    end

    ### save variables
    model.var["Phase"] = phase

    return nothing
end

function load_balance!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer

    num_buses = get_num_buses(inputs.buses)

    ### get model expressions
    generation_per_bus = model.expr["GenerationPerBus"]
    power_injection = model.expr["PowerInjection"]
    power_loss_per_bus = model.expr["PowerLossPerBus"]

    ### create constraints
    load_balance = constraintref(num_buses)

    ### define variables and expressions

    ### define constraints
    for bus in 1:num_buses
        load_balance[bus] = @constraint(
            optimizer_model,
            generation_per_bus[bus] == 
                get_bus_demand(inputs.buses, bus)
                + power_injection[bus] + power_loss_per_bus[bus]
        )
    end

    ### save constraints
    model.con["LoadBalance"] = load_balance

    return nothing
end

function active_flow!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer

    num_buses = get_num_buses(inputs.buses)
    num_branches = get_num_branches(inputs.branches)

    ### get model variables
    phase = model.var["Phase"]

    ### create variables and expressions
    flow = zeros(AffExpr, num_branches)
    power_injection = zeros(AffExpr, num_buses)

    ### create constraints
    flow_lower_bound = constraintref(num_branches)
    flow_upper_bound = constraintref(num_branches)

    ### define variables and expressions
    for branch in 1:num_branches
        bus_from, bus_to = get_buses_in_branch(inputs, branch)
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

    ### define constraints
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

    ### save variables and expressions
    model.expr["Flow"] = flow
    model.expr["PowerInjection"] = power_injection

    ### save constraints
    model.con["FlowLowerBound"] = flow_lower_bound
    model.con["FlowUpperBound"] = flow_upper_bound

    return nothing
end

function active_loss!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer

    num_buses = get_num_buses(inputs.buses)
    num_branches = get_num_branches(inputs.branches)

    ### create and save variables and expressions
    if !inputs.consider_losses
        power_loss = zeros(AffExpr, num_branches)
        power_loss_per_bus = zeros(AffExpr, num_buses)
        model.expr["PowerLoss"] = power_loss
        model.expr["PowerLossPerBus"] = power_loss_per_bus
    else
        if inputs.linearize_loss
            power_loss_var = variableref(num_branches)
            power_loss = zeros(AffExpr, num_branches)

            # start variables
            start_power_loss = fill(nothing, (size(power_loss_var)))
            if inputs.consider_variable_initialization && inputs.initialize_variables["Iteration"] > 1
                start_power_loss = inputs.initialize_variables["PowerLossVar"]
            end
            
            for branch in 1:num_branches
                power_loss_var[branch] = @variable(
                    optimizer_model,
                    lower_bound = 0.0,
                    start = start_power_loss[branch],
                )
                power_loss[branch] = power_loss_var[branch]
            end
            power_loss_per_bus = zeros(AffExpr, num_buses)
            model.expr["PowerLossPerBus"] = power_loss_per_bus
            model.expr["PowerLoss"] = power_loss
            model.var["PowerLossVar"] = power_loss_var
        else
            power_loss = zeros(QuadExpr, num_branches)
            power_loss_per_bus = zeros(QuadExpr, num_buses)
            model.expr["PowerLoss"] = power_loss
            model.expr["PowerLossPerBus"] = power_loss_per_bus
        end
    end

    ### define variables, expressions and constraints
    if inputs.consider_losses
        if inputs.linearize_loss
            # creates epigraphs with power loss cuts
            loss_cuts!(model, inputs)
        else
            quadratic_loss!(model, inputs)
        end
    end
    for branch in 1:num_branches
        bus_from, bus_to = get_buses_in_branch(inputs, branch)
        power_loss_per_bus[bus_from] = @expression(
            optimizer_model,
            power_loss_per_bus[bus_from] + power_loss[branch]/2
        )
        power_loss_per_bus[bus_to] = @expression(
            optimizer_model,
            power_loss_per_bus[bus_to] + power_loss[branch]/2
        )
    end

    return nothing
end

function generation!(model::DCOPFModel, inputs::DCOPFInputs)
    optimizer_model = model.optimizer

    num_buses = get_num_buses(inputs.buses)
    num_generators = get_num_generators(inputs.generators)

    ### create variables and expressions
    generation = variableref(num_generators)
    generation_per_bus = zeros(AffExpr, num_buses)
    commit = variableref(num_generators)
    commit_expr = ones(AffExpr, num_generators)

    ### create constraints
    commit_constraint_lower = constraintref(num_generators)
    commit_constraint_upper = constraintref(num_generators)

    ### define variables and expressions
    for gen in 1:num_generators

        # start variables
        start_generation = fill(nothing, (size(generation)))
        start_commit = fill(nothing, (size(commit)))
        if inputs.consider_variable_initialization && inputs.initialize_variables["Iteration"] > 1
            start_generation = inputs.initialize_variables["Generation"]
            start_commit = inputs.initialize_variables["Commit"]
        end

        generation[gen] = @variable(
            optimizer_model,
            lower_bound = get_min_generation(inputs.generators, gen),
            upper_bound = get_max_generation(inputs.generators, gen),
            start = start_generation[gen],
        )
        # add binaries only if generator has on cost
        if generator_has_on_cost(inputs.generators, gen)
            commit[gen] = @variable(
                optimizer_model,
                binary = true,
                start = start_commit[gen],
            )
            commit_expr[gen] = commit[gen]
            if inputs.fix_variables["FixCommit"]
                if isassigned(inputs.fix_variables["Commit"], gen)
                    JuMP.fix(commit[gen], inputs.fix_variables["Commit"][gen]; force = true)
                    JuMP.unset_binary(commit[gen])
                end
            end
        end
    end
    for bus in 1:num_buses
        for gen in generators_in_bus(inputs.generators, inputs.buses.id[bus])
            generation_per_bus[bus] = @expression(
                optimizer_model,
                generation_per_bus[bus] + generation[gen]
            )
        end
    end

    ### define constraints
    for gen in 1:num_generators
        commit_constraint_lower[gen] = @constraint(
            optimizer_model,
            generation[gen] >= get_min_generation(inputs.generators, gen) * commit_expr[gen]
        )
        commit_constraint_upper[gen] = @constraint(
            optimizer_model,
            generation[gen] <= get_max_generation(inputs.generators, gen) * commit_expr[gen]
        )
    end

    ### save variables and expressions
    model.var["Generation"] = generation
    model.expr["GenerationPerBus"] = generation_per_bus
    model.var["Commit"] = commit
    model.expr["CommitExpr"] = commit_expr

    ### save constraints
    model.con["CommitConstraintLower"] = commit_constraint_lower
    model.con["CommitConstraintUpper"] = commit_constraint_upper

    return nothing
end

function fix_commit!(model::DCOPFModel, value::Vector{Int})
    commit = 1
end

function linear_flow!(args...)
    phase!(args...)
    active_loss!(args...)
    active_flow!(args...)
    generation!(args...)
    load_balance!(args...)
    return nothing
end

function loss_cuts!(model::DCOPFModel, inputs::DCOPFInputs)
    num_branches = get_num_branches(inputs.branches)
    phase = model.var["Phase"]
    # get key and elements in model.cuts dictionary
    for (k, group) in model.cuts
        if "PowerLoss" in k
            for branch in 1:num_branches
                bus_from, bus_to = get_buses_in_branch(inputs, branch)
                @constraint(
                    model.optimizer,
                    model.expr["PowerLoss"][branch] >= 
                        [phase[bus_from] - phase[bus_to], 1]' * group[branch]
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
    if inputs.num_cuts_per_iteration > 1
        @info "multiple cuts per iteration"
        single_cut!(model, inputs, results, current_iteration)
        multiple_cuts!(model, inputs, results, current_iteration)
    else
        @info "one cut per iteration"
        single_cut!(model, inputs, results, current_iteration)
    end
end

function single_cut!(
    model::DCOPFModel,
    inputs::DCOPFInputs,
    results::DCOPFResults,
    current_iteration::Int
)
    num_branches = get_num_branches(inputs.branches)

    phase = results.var["Phase", current_iteration]
    loss_cut = Array{Vector{Float64}, 1}(undef, num_branches)
    loss = zeros(num_branches)

    for branch in 1:num_branches
        bus_from, bus_to = get_buses_in_branch(inputs, branch)
        phase_difference = phase[bus_from] - phase[bus_to]
        conductance = get_conductance(inputs.branches, branch)
        loss_derivative = transmission_loss_derivative(phase_difference, conductance)
        loss[branch] = transmission_loss(phase_difference, conductance)
        # cut is a vector [a, b] where y = a*x + b
        loss_cut[branch] = [loss_derivative, loss[branch] - (loss_derivative * phase_difference)]
    end
    if maximum(abs.(loss - results.expr["PowerLoss", current_iteration])) <= inputs.tolerance
        return :stop
    else
        if inputs.num_cuts_per_iteration > 1
            idx = max_number_in_dict_tuple_key(model.cuts, "PowerLoss")
        else
            idx = current_iteration
        end
        model.cuts["PowerLoss", current_iteration] = loss_cut
        return nothing
    end  
end

function multiple_cuts!(
    model::DCOPFModel,
    inputs::DCOPFInputs,
    results::DCOPFResults,
    current_iteration::Int
)
    num_branches = get_num_branches(inputs.branches)

    phase = results.var["Phase", current_iteration]
    loss_cut = Array{Vector{Float64}, 1}(undef, num_branches)
    loss = zeros(num_branches)

    max_power_loss_idx = max_number_in_dict_tuple_key(model.cuts, "PowerLoss")

    num_cuts = inputs.num_cuts_per_iteration
    cuts_coef = LinRange(1, 1+1/(10^(num_cuts-1)), num_cuts)

    for cut in 2:num_cuts
        for branch in 1:num_branches
            bus_from, bus_to = get_buses_in_branch(inputs, branch)
            phase_difference = (phase[bus_from] - phase[bus_to])*(cuts_coef[cut])
            conductance = get_conductance(inputs.branches, branch)
            loss_derivative = transmission_loss_derivative(phase_difference, conductance)
            loss[branch] = transmission_loss(phase_difference, conductance)
            # cut is a vector [a, b] where y = a*x + b
            loss_cut[branch] = [loss_derivative, loss[branch] - (loss_derivative * phase_difference)]
        end
        model.cuts["PowerLoss", max_power_loss_idx + cut - 1] = loss_cut
    end
end

function quadratic_loss!(model::DCOPFModel, inputs::DCOPFInputs)
    num_branches = get_num_branches(inputs.branches)

    power_loss = model.expr["PowerLoss"]
    phase = model.var["Phase"]

    for branch in 1:num_branches
        conductance = get_conductance(inputs.branches, branch)
        bus_from, bus_to = get_buses_in_branch(inputs, branch)
        power_loss[branch] = @expression(
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
