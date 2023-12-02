using JuMP, HiGHS, Ipopt

function case_3_buses_no_loss_no_cuts()
    buses = DCOPF.DCOPFBuses()
    generators = DCOPF.DCOPFGenerators()
    branches = DCOPF.DCOPFBranches()
    
    # load buses
    buses.id = 1:3
    buses.type = [3, 1, 1]
    buses.active_demand = [0, 0, .8]
    
    # load generators
    generators.min_generation = zeros(2)
    generators.max_generation = [.5, .5]
    generators.cost = [.5, 1]
    generators.bus_id = [1, 2]
    
    # load branches
    branches.bus_from = [1, 1, 2]
    branches.bus_to = [2, 3, 3]
    branches.resistance = [0.0, 0.0, 0.0]
    branches.reactance = [.1, .08, .05]
    branches.max_flow = [.1, .5, .5]
    
    inputs = DCOPF.DCOPFInputs()
    
    inputs.buses = buses
    inputs.branches = branches
    inputs.generators = generators
    
    model = DCOPF.DCOPFModel()
    model.optimizer = Model(HiGHS.Optimizer)
    
    DCOPF.linear_flow!(model, inputs)
    generation = model.var["Generation"]
    @objective(model.optimizer, Min, sum(generators.cost .* generation))
    optimize!(model.optimizer)
    
    results = DCOPF.DCOPFResults()
    DCOPF.save_all_results!(model, results, 1)

    return results
end

function case_3_buses_no_loss_with_cuts()
    buses = DCOPF.DCOPFBuses()
    generators = DCOPF.DCOPFGenerators()
    branches = DCOPF.DCOPFBranches()

    # load buses
    buses.id = 1:3
    buses.type = [3, 1, 1]
    buses.active_demand = [0, 0, .8]

    # load generators
    generators.min_generation = zeros(2)
    generators.max_generation = [.5, .5]
    generators.cost = [.5, 1]
    generators.bus_id = [1, 2]

    # load branches
    branches.bus_from = [1, 1, 2]
    branches.bus_to = [2, 3, 3]
    branches.resistance = [0, 0, 0]
    branches.reactance = [.1, .08, .05]
    branches.max_flow = [.1, .5, .5]

    inputs = DCOPF.DCOPFInputs()

    inputs.buses = buses
    inputs.branches = branches
    inputs.generators = generators
    inputs.consider_losses = true
    inputs.linearize_loss = true
    inputs.max_iteration = 10
    inputs.tolerance = 1e-8

    model = DCOPF.DCOPFModel()
    results = DCOPF.DCOPFResults()

    it = 0
    for iteration in 1:inputs.max_iteration
        it += 1
        @info "Iteration $iteration"
        model.optimizer = Model(HiGHS.Optimizer)

        DCOPF.linear_flow!(model, inputs)
        generation = model.var["Generation"]
        @objective(model.optimizer, Min, sum(generators.cost .* generation))
        optimize!(model.optimizer)

        DCOPF.save_all_results!(model, results, iteration)
        
        new_cut = DCOPF.new_loss_cut!(model, inputs, results, iteration)
        if new_cut == :stop
            @info "Optimal found"
            break
        end
    end
    return results, it
end

function case_3_buses_with_loss_with_cuts()
    buses = DCOPF.DCOPFBuses()
    generators = DCOPF.DCOPFGenerators()
    branches = DCOPF.DCOPFBranches()

    # load buses
    buses.id = 1:3
    buses.type = [3, 1, 1]
    buses.active_demand = [0, 0, .8]

    # load generators
    generators.min_generation = zeros(2)
    generators.max_generation = [.5, .5]
    generators.cost = [.5, 1]
    generators.bus_id = [1, 2]

    # load branches
    branches.bus_from = [1, 1, 2]
    branches.bus_to = [2, 3, 3]
    branches.resistance = [.04, .01, .02]
    branches.reactance = [-.4, -.25, -.2]
    branches.max_flow = [.1, .5, .5]

    inputs = DCOPF.DCOPFInputs()

    inputs.buses = buses
    inputs.branches = branches
    inputs.generators = generators
    inputs.consider_losses = true
    inputs.linearize_loss = true
    inputs.max_iteration = 10
    inputs.tolerance = 1e-8

    model = DCOPF.DCOPFModel()
    results = DCOPF.DCOPFResults()

    it = 0
    for iteration in 1:inputs.max_iteration
        it += 1
        @info "Iteration $iteration"
        model.optimizer = Model(HiGHS.Optimizer)

        DCOPF.linear_flow!(model, inputs)
        generation = model.var["Generation"]
        @objective(model.optimizer, Min, sum(generators.cost .* generation))
        optimize!(model.optimizer)

        DCOPF.save_all_results!(model, results, iteration)
        
        new_cut = DCOPF.new_loss_cut!(model, inputs, results, iteration)
        if new_cut == :stop
            @info "Optimal found"
            break
        end
    end

    return results, it
end

function case_3_buses_with_loss_quadratic_formulation()
    buses = DCOPF.DCOPFBuses()
    generators = DCOPF.DCOPFGenerators()
    branches = DCOPF.DCOPFBranches()

    # load buses
    buses.id = 1:3
    buses.type = [3, 1, 1]
    buses.active_demand = [0, 0, .8]

    # load generators
    generators.min_generation = zeros(2)
    generators.max_generation = [.5, .5]
    generators.cost = [.5, 1]
    generators.bus_id = [1, 2]

    # load branches
    branches.bus_from = [1, 1, 2]
    branches.bus_to = [2, 3, 3]
    branches.resistance = [.04, .01, .02]
    branches.reactance = [-.4, -.25, -.2]
    branches.max_flow = [.1, .5, .5]

    inputs = DCOPF.DCOPFInputs()

    inputs.buses = buses
    inputs.branches = branches
    inputs.generators = generators
    inputs.consider_losses = true
    inputs.linearize_loss = false
    inputs.max_iteration = 10
    inputs.tolerance = 1e-8

    model = DCOPF.DCOPFModel()
    model.optimizer = Model(Ipopt.Optimizer)

    DCOPF.linear_flow!(model, inputs)
    generation = model.var["Generation"]
    @objective(model.optimizer, Min, sum(generators.cost .* generation))
    optimize!(model.optimizer)

    results = DCOPF.DCOPFResults()
    DCOPF.save_all_results!(model, results, 1)

    return results
end