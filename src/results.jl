function save_all_results!(model::DCOPFModel, results::DCOPFResults, current_iteration::Int)
    for (key, group) in model.var
        var_values = fill(NaN, size(group))
        for i in eachindex(group)
            if isassigned(group, i)
                var_values[i] = JuMP.value(group[i])
            end
        end
        results.var[key, current_iteration] = var_values
    end
    for (key, group) in model.expr
        expr_values = fill(NaN, size(group))
        for i in eachindex(group)
            if isassigned(group, i)
                expr_values[i] = JuMP.value(group[i])
            end
        end
        results.expr[key, current_iteration] = expr_values
    end
    save_solution_quality!(model, results, current_iteration)
    return nothing
end

function save_solution_quality!(model::DCOPFModel, results::DCOPFResults, current_iteration::Int)
    results.solution_quality.solver_time[current_iteration] = JuMP.solve_time(model.optimizer)
    # results.solution_quality.gap[current_iteration] = JuMP.relative_gap(model.optimizer)
    results.solution_quality.objective_value[current_iteration] = JuMP.objective_value(model.optimizer)
end

function write_branch_results(inputs::DCOPFInputs, results::DCOPFResults)
    last_it = maximum(keys(results.solution_quality.solver_time))
    Sb = inputs.power_base
    branches_df = DataFrame(
        "Bus from" => inputs.branches.bus_from,
        "Bus to" => inputs.branches.bus_to,
        "Max Flow (MW)" => inputs.branches.max_flow * Sb,
        "Flow (MW)" => results.expr["Flow", last_it] * Sb,
        "Power Loss (MW)" => results.expr["PowerLoss", last_it] * Sb, 
    )
    return branches_df
end

function write_bus_results(inputs::DCOPFInputs, results::DCOPFResults)
    last_it = maximum(keys(results.solution_quality.solver_time))
    Sb = inputs.power_base
    buses_df = DataFrame(
        "Bus" => inputs.buses.id,
        "Demand (MW)" => inputs.buses.active_demand * Sb,
        "Phase (deg)" => rad2deg.(results.var["Phase", last_it]),
    )
    return buses_df
end

function write_generation_results(inputs::DCOPFInputs, results::DCOPFResults)
    last_it = maximum(keys(results.solution_quality.solver_time))
    Sb = inputs.power_base
    generation_df = DataFrame(
        "Bus" => inputs.generators.bus_id,
        "Cost" => inputs.generators.cost,
        "Min Generation (MW)" => inputs.generators.min_generation * Sb,
        "Max Generation (MW)" => inputs.generators.max_generation * Sb,
        "Generation (MW)" => results.var["Generation", last_it] * Sb,
    )
    return generation_df
end

function write_all_data_frames(inputs, results)
    branch_df = write_branch_results(inputs, results)
    bus_df = write_bus_results(inputs, results)
    gen_df = write_generation_results(inputs, results)
    return branch_df, bus_df, gen_df
end

function plot_cuts(inputs::DCOPFInputs, model::DCOPFModel, results::DCOPFResults, branch::Int)
    Plots.plotly()
    last_it = maximum(keys(results.solution_quality.solver_time))
    x = LinRange(-.4,.4,100)
    tl = zeros(100);
    for i in eachindex(x)                                                                                             
        tl[i] = transmission_loss(x[i], get_conductance(inputs.branches, branch))                                                 
    end
    plt = plot(x, tl, label = "Perdas originais (quadrática)")
    for i in 2:last_it
        v = model.cuts[("PowerLoss", i-1)][branch]
        reshape(v, length(v), 1)
        y = [x ones(100)] * v
        plt = plot!(x, y, label = "Corte iteração $(i-1)")
    end
    plt = plot!(legend = :outertopright, ylabel = "Perdas (pu)", xlabel = "Fase (rad)")
    plt = plot!(title = "Linha $branch", size = (800, 400))
end
