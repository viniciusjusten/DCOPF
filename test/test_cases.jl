module TestCases

using Test
using JuMP, HiGHS
import DCOPF

function test_case_no_loss_no_cuts()
    model = DCOPF.DCOPFModel()
    model.optimizer = Model(HiGHS.Optimizer)
    
    inputs = DCOPF.DCOPFInputs()
    inputs.Ybus = [ 22.5im -10im -12.5im; -10im 30im -20im; -12.5im -20im 32.5im ]
    inputs.demand = [0, 0, .8]
    inputs.min_generation = zeros(3)
    inputs.max_generation = [.5, .5, 0]
    max_flow = [0 .1 .5; .1 0 .5; .5 .5 0]
    inputs.min_flow = -max_flow
    inputs.max_flow = max_flow
    cost = [.5, 1, 0]
    inputs.generation_cost = cost
    
    DCOPF.linear_flow!(model, inputs)
    generation = model.var["Generation"]
    @objective(model.optimizer, Min, sum(cost .* generation))
    optimize!(model.optimizer)
    
    results = DCOPF.DCOPFResults()
    DCOPF.save_all_results!(model, results, 1)
    
    for i in 1:3
        @test isapprox(
            results.var["Generation", 1][i],
            [0.48461538461538467, 0.31538461538461543, 0.0][i],
            atol = 1e-4
        )
    end
    @test isapprox(
        results.expr["Flow", 1][1,2],
        0.1,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", 1][1,3],
        0.384615,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", 1][2,3],
        0.415385,
        atol = 1e-4
    )
end

function test_case_no_loss_with_cuts()
    model = DCOPF.DCOPFModel()

    inputs = DCOPF.DCOPFInputs()
    inputs.Ybus = [ 22.5im -10im -12.5im; -10im 30im -20im; -12.5im -20im 32.5im ]
    inputs.demand = [0, 0, .8]
    inputs.min_generation = zeros(3)
    inputs.max_generation = [.5, .5, 0]
    max_flow = [0 .1 .5; .1 0 .5; .5 .5 0]
    inputs.min_flow = -max_flow
    inputs.max_flow = max_flow
    cost = [.5, 1, 0]
    inputs.generation_cost = cost
    max_iteration = 10
    inputs.max_iteration = max_iteration
    inputs.consider_losses = true
    inputs.linearize_loss = true
    inputs.tolerance = 1e-5

    results = DCOPF.DCOPFResults()

    t_sem_perdas_com_corte = 0
    it = 0
    for iteration in 1:max_iteration
        it += 1
        @info "Iteration $iteration"
        model.optimizer = Model(HiGHS.Optimizer)
        DCOPF.linear_flow!(model, inputs)
        generation = model.var["Generation"]
        @objective(model.optimizer, Min, sum(cost .* generation))
        optimize!(model.optimizer)
        t_sem_perdas_com_corte += JuMP.solve_time(model.optimizer)
        DCOPF.save_all_results!(model, results, iteration)
        new_cut = DCOPF.new_loss_cut!(model, inputs, results, iteration)
        if new_cut == :stop
            @info "Optimal found"
            break
        end
    end
    
    @test it == 1
    for i in 1:3
        @test isapprox(
            results.var["Generation", 1][i],
            [0.48461538461538467, 0.31538461538461543, 0.0][i],
            atol = 1e-4
        )
    end
    @test isapprox(
        results.expr["Flow", 1][1,2],
        0.1,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", 1][1,3],
        0.384615,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", 1][2,3],
        0.415385,
        atol = 1e-4
    )
end

function test_case_with_loss_with_cuts()
    ### with actual loss
    model = DCOPF.DCOPFModel()

    inputs = DCOPF.DCOPFInputs()
    inputs.Ybus = ([ 0.05 - 0.65im -0.04 + 0.4im -0.01 + 0.25im;
                    -0.04 + 0.4im 0.06 - 0.6im -0.02 + 0.2im;
                    -0.01 + 0.25im -0.02 + 0.2im 0.03 - 0.45im
                    ]).^-1
    inputs.demand = [0, 0, .8]
    inputs.min_generation = zeros(3)
    inputs.max_generation = [.5, .5, 0]
    max_flow = [0 .1 .5; .1 0 .5; .5 .5 0]
    inputs.min_flow = -max_flow
    inputs.max_flow = max_flow
    cost = [.5, 1, 0]
    inputs.generation_cost = cost
    max_iteration = 10
    inputs.max_iteration = max_iteration
    inputs.consider_losses = true
    inputs.linearize_loss = true
    inputs.tolerance = 1e-10

    results = DCOPF.DCOPFResults()

    t_com_perdas_com_corte = 0
    it = 0
    for iteration in 1:max_iteration
        it += 1
        @info "Iteration $iteration"
        model.optimizer = Model(HiGHS.Optimizer)
        DCOPF.linear_flow!(model, inputs)
        generation = model.var["Generation"]
        @objective(model.optimizer, Min, sum(cost .* generation))
        optimize!(model.optimizer)
        t_com_perdas_com_corte += JuMP.solve_time(model.optimizer)
        DCOPF.save_all_results!(model, results, iteration)
        new_cut = DCOPF.new_loss_cut!(model, inputs, results, iteration)
        if new_cut == :stop
            @info "Optimal found"
            break
        end
    end

    for i in 1:3
        @test isapprox(
            results.var["Generation", it][i],
            [0.5, 0.3048567229073016, 0.0][i],
            atol = 1e-4
        )
    end
      
    @test isapprox(
        results.expr["Flow", it][1,2],
        0.0753919,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", it][1,3],
        0.4236,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", it][2,3],
        0.378716,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["PowerLoss", it][1,2],
        0.000225106,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["PowerLoss", it][1,3],
        0.0017915,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["PowerLoss", it][2,3],
        0.00284011,
        atol = 1e-4
    )
end

    function runtests()
        for name in names(@__MODULE__; all = true)
            if startswith("$name", "test_")
                @testset "$(name)" begin
                    getfield(@__MODULE__, name)()
                end
            end
        end
    end
    
    TestCases.runtests()
end
