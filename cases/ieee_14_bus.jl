using JuMP, HiGHS, Ipopt

############## ieee 14 bus ##############
function case_14_with_loss_with_cuts()
    bus = [
        1	 3	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        2	 2	 21.7	 12.7	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        3	 2	 94.2	 19.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        4	 1	 47.8	 -3.9	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        5	 1	 7.6	 1.6	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        6	 2	 11.2	 7.5	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        7	 1	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        8	 2	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        9	 1	 29.5	 16.6	 0.0	 19.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        10	 1	 9.0	 5.8	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        11	 1	 3.5	 1.8	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        12	 1	 6.1	 1.6	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        13	 1	 13.5	 5.8	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        14	 1	 14.9	 5.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
    ];

    gen = [
        1	 170.0	 5.0	 10.0	 0.0	 1.0	 100.0	 1	 340	 0.0;
        2	 29.5	 0.0	 30.0	 -30.0	 1.0	 100.0	 1	 59	 0.0;
        3	 0.0	 20.0	 40.0	 0.0	 1.0	 100.0	 1	 100	 0.0;
        6	 0.0	 9.0	 24.0	 -6.0	 1.0	 100.0	 1	 100	 0.0;
        8	 0.0	 9.0	 24.0	 -6.0	 1.0	 100.0	 1	 100	 0.0;
    ];

    branch = [
        1	 2	 0.01938	 0.05917	 0.0528	 472	 472	 472	 0.0	 0.0	 1	 -30.0	 30.0;
        1	 5	 0.05403	 0.22304	 0.0492	 128	 128	 128	 0.0	 0.0	 1	 -30.0	 30.0;
        2	 3	 0.04699	 0.19797	 0.0438	 145	 145	 145	 0.0	 0.0	 1	 -30.0	 30.0;
        2	 4	 0.05811	 0.17632	 0.034	 158	 158	 158	 0.0	 0.0	 1	 -30.0	 30.0;
        2	 5	 0.05695	 0.17388	 0.0346	 161	 161	 161	 0.0	 0.0	 1	 -30.0	 30.0;
        3	 4	 0.06701	 0.17103	 0.0128	 160	 160	 160	 0.0	 0.0	 1	 -30.0	 30.0;
        4	 5	 0.01335	 0.04211	 0.0	 664	 664	 664	 0.0	 0.0	 1	 -30.0	 30.0;
        4	 7	 0.0	 0.20912	 0.0	 141	 141	 141	 0.978	 0.0	 1	 -30.0	 30.0;
        4	 9	 0.0	 0.55618	 0.0	 53	 53	 53	 0.969	 0.0	 1	 -30.0	 30.0;
        5	 6	 0.0	 0.25202	 0.0	 117	 117	 117	 0.932	 0.0	 1	 -30.0	 30.0;
        6	 11	 0.09498	 0.1989	 0.0	 134	 134	 134	 0.0	 0.0	 1	 -30.0	 30.0;
        6	 12	 0.12291	 0.25581	 0.0	 104	 104	 104	 0.0	 0.0	 1	 -30.0	 30.0;
        6	 13	 0.06615	 0.13027	 0.0	 201	 201	 201	 0.0	 0.0	 1	 -30.0	 30.0;
        7	 8	 0.0	 0.17615	 0.0	 167	 167	 167	 0.0	 0.0	 1	 -30.0	 30.0;
        7	 9	 0.0	 0.11001	 0.0	 267	 267	 267	 0.0	 0.0	 1	 -30.0	 30.0;
        9	 10	 0.03181	 0.0845	 0.0	 325	 325	 325	 0.0	 0.0	 1	 -30.0	 30.0;
        9	 14	 0.12711	 0.27038	 0.0	 99	 99	 99	 0.0	 0.0	 1	 -30.0	 30.0;
        10	 11	 0.08205	 0.19207	 0.0	 141	 141	 141	 0.0	 0.0	 1	 -30.0	 30.0;
        12	 13	 0.22092	 0.19988	 0.0	 99	 99	 99	 0.0	 0.0	 1	 -30.0	 30.0;
        13	 14	 0.17093	 0.34802	 0.0	 76	 76	 76	 0.0	 0.0	 1	 -30.0	 30.0;
    ];

    buses = DCOPF.DCOPFBuses()
    generators = DCOPF.DCOPFGenerators()
    branches = DCOPF.DCOPFBranches()

    # load buses
    buses.id = Int.(bus[1:end, 1])
    buses.type = Int.(bus[1:end, 2])
    buses.active_demand = bus[1:end, 3]/100

    # load generators
    generators.min_generation = gen[1:end, 10]/100
    generators.max_generation = gen[1:end, 9]/100
    generators.cost = gen[1:end, 1]
    generators.bus_id = Int.(gen[1:end, 1])

    # load branches
    branches.bus_from = branch[1:end, 1]
    branches.bus_to = branch[1:end, 2]
    branches.resistance = branch[1:end, 3]
    branches.reactance = branch[1:end, 4]
    branches.max_flow = branch[1:end, 6]/100

    inputs = DCOPF.DCOPFInputs()

    inputs.buses = buses
    inputs.branches = branches
    inputs.generators = generators
    inputs.consider_losses = true
    inputs.linearize_loss = true
    inputs.max_iteration = 20
    inputs.tolerance = 1e-6

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
    return results, DCOPF.write_all_data_frames(inputs, results)
end

function case_14_with_loss_quadratic()
    ############## ieee 14 bus ##############
    bus = [
        1	 3	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        2	 2	 21.7	 12.7	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        3	 2	 94.2	 19.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        4	 1	 47.8	 -3.9	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        5	 1	 7.6	 1.6	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        6	 2	 11.2	 7.5	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        7	 1	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        8	 2	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        9	 1	 29.5	 16.6	 0.0	 19.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        10	 1	 9.0	 5.8	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        11	 1	 3.5	 1.8	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        12	 1	 6.1	 1.6	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        13	 1	 13.5	 5.8	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
        14	 1	 14.9	 5.0	 0.0	 0.0	 1	    1.00000	    0.00000	 1.0	 1	    1.06000	    0.94000;
    ];

    gen = [
        1	 170.0	 5.0	 10.0	 0.0	 1.0	 100.0	 1	 340	 0.0;
        2	 29.5	 0.0	 30.0	 -30.0	 1.0	 100.0	 1	 59	 0.0;
        3	 0.0	 20.0	 40.0	 0.0	 1.0	 100.0	 1	 100	 0.0;
        6	 0.0	 9.0	 24.0	 -6.0	 1.0	 100.0	 1	 100	 0.0;
        8	 0.0	 9.0	 24.0	 -6.0	 1.0	 100.0	 1	 100	 0.0;
    ];

    branch = [
        1	 2	 0.01938	 0.05917	 0.0528	 472	 472	 472	 0.0	 0.0	 1	 -30.0	 30.0;
        1	 5	 0.05403	 0.22304	 0.0492	 128	 128	 128	 0.0	 0.0	 1	 -30.0	 30.0;
        2	 3	 0.04699	 0.19797	 0.0438	 145	 145	 145	 0.0	 0.0	 1	 -30.0	 30.0;
        2	 4	 0.05811	 0.17632	 0.034	 158	 158	 158	 0.0	 0.0	 1	 -30.0	 30.0;
        2	 5	 0.05695	 0.17388	 0.0346	 161	 161	 161	 0.0	 0.0	 1	 -30.0	 30.0;
        3	 4	 0.06701	 0.17103	 0.0128	 160	 160	 160	 0.0	 0.0	 1	 -30.0	 30.0;
        4	 5	 0.01335	 0.04211	 0.0	 664	 664	 664	 0.0	 0.0	 1	 -30.0	 30.0;
        4	 7	 0.0	 0.20912	 0.0	 141	 141	 141	 0.978	 0.0	 1	 -30.0	 30.0;
        4	 9	 0.0	 0.55618	 0.0	 53	 53	 53	 0.969	 0.0	 1	 -30.0	 30.0;
        5	 6	 0.0	 0.25202	 0.0	 117	 117	 117	 0.932	 0.0	 1	 -30.0	 30.0;
        6	 11	 0.09498	 0.1989	 0.0	 134	 134	 134	 0.0	 0.0	 1	 -30.0	 30.0;
        6	 12	 0.12291	 0.25581	 0.0	 104	 104	 104	 0.0	 0.0	 1	 -30.0	 30.0;
        6	 13	 0.06615	 0.13027	 0.0	 201	 201	 201	 0.0	 0.0	 1	 -30.0	 30.0;
        7	 8	 0.0	 0.17615	 0.0	 167	 167	 167	 0.0	 0.0	 1	 -30.0	 30.0;
        7	 9	 0.0	 0.11001	 0.0	 267	 267	 267	 0.0	 0.0	 1	 -30.0	 30.0;
        9	 10	 0.03181	 0.0845	 0.0	 325	 325	 325	 0.0	 0.0	 1	 -30.0	 30.0;
        9	 14	 0.12711	 0.27038	 0.0	 99	 99	 99	 0.0	 0.0	 1	 -30.0	 30.0;
        10	 11	 0.08205	 0.19207	 0.0	 141	 141	 141	 0.0	 0.0	 1	 -30.0	 30.0;
        12	 13	 0.22092	 0.19988	 0.0	 99	 99	 99	 0.0	 0.0	 1	 -30.0	 30.0;
        13	 14	 0.17093	 0.34802	 0.0	 76	 76	 76	 0.0	 0.0	 1	 -30.0	 30.0;
    ];

    buses = DCOPF.DCOPFBuses()
    generators = DCOPF.DCOPFGenerators()
    branches = DCOPF.DCOPFBranches()

    # load buses
    buses.id = Int.(bus[1:end, 1])
    buses.type = Int.(bus[1:end, 2])
    buses.active_demand = bus[1:end, 3]/100

    # load generators
    generators.min_generation = gen[1:end, 10]/100
    generators.max_generation = gen[1:end, 9]/100
    generators.cost = gen[1:end, 1]
    generators.bus_id = Int.(gen[1:end, 1])

    # load branches
    branches.bus_from = branch[1:end, 1]
    branches.bus_to = branch[1:end, 2]
    branches.resistance = branch[1:end, 3]
    branches.reactance = branch[1:end, 4]
    branches.max_flow = branch[1:end, 6]/100

    inputs = DCOPF.DCOPFInputs()

    inputs.buses = buses
    inputs.branches = branches
    inputs.generators = generators
    inputs.consider_losses = true
    inputs.linearize_loss = false
    inputs.max_iteration = 20
    inputs.tolerance = 1e-6

    model = DCOPF.DCOPFModel()
    results = DCOPF.DCOPFResults()

    it = 1

    model.optimizer = Model(Ipopt.Optimizer)

    DCOPF.linear_flow!(model, inputs)
    generation = model.var["Generation"]
    @objective(model.optimizer, Min, sum(generators.cost .* generation))
    optimize!(model.optimizer)

    DCOPF.save_all_results!(model, results, it)

    return results, DCOPF.write_all_data_frames(inputs, results)
end