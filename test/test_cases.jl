module TestCases

using Test
import DCOPF

include(joinpath(dirname(@__DIR__), "cases", "3_buses.jl"))

function test_case_no_loss_no_cuts()
    results = case_3_buses_no_loss_no_cuts()
    for i in 1:2
        @test isapprox(
            results.var["Generation", 1][i],
            [0.48461538461538467, 0.31538461538461543][i],
            atol = 1e-4
        )
    end
    @test isapprox(
        results.expr["Flow", 1][1],
        0.1,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", 1][2],
        0.384615,
        atol = 1e-4
    )
    @test isapprox(
        results.expr["Flow", 1][3],
        0.415385,
        atol = 1e-4
    )
end

function test_if_case_no_loss_with_cuts_matches_case_no_loss_no_cuts()
    r1 = case_3_buses_no_loss_no_cuts()
    r2, it = case_3_buses_no_loss_with_cuts()
    @test it == 1
    @test isapprox(r1.var["Generation", 1], r2.var["Generation", 1], atol = 1e-6)
    @test isapprox(r1.var["Phase", 1], r2.var["Phase", 1], atol = 1e-6)
    @test isapprox(r1.expr["Flow", 1], r2.expr["Flow", 1], atol = 1e-6)
    @test isapprox(r1.expr["PowerLoss", 1], r2.expr["PowerLoss", 1], atol = 1e-6)
end

function test_if_case_with_loss_and_cuts_matches_case_with_loss_and_quadratic()
    r1 = case_3_buses_with_loss_quadratic_formulation()
    r2, it = case_3_buses_with_loss_with_cuts()
    @test isapprox(r1.var["Generation", 1], r2.var["Generation", it], atol = 1e-6)
    @test isapprox(r1.var["Phase", 1], r2.var["Phase", it], atol = 1e-6)
    @test isapprox(r1.expr["Flow", 1], r2.expr["Flow", it], atol = 1e-6)
    @test isapprox(r1.expr["PowerLoss", 1], r2.expr["PowerLoss", it], atol = 1e-6)
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
