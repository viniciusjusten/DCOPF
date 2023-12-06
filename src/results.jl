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

function save_shadow_prices!(model::DCOPFModel, results::DCOPFResults)
    results.shadow_prices["MarginalCostPerBus"] = JuMP.shadow_price.(model.con["LoadBalance"])
    results.shadow_prices["NegativeFlowAtMax"] = JuMP.shadow_price.(model.con["FlowLowerBound"])
    results.shadow_prices["PositiveFlowAtMax"] = JuMP.shadow_price.(model.con["FlowUpperBound"])
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

    if in_keys(results.shadow_prices, "NegativeFlowAtMax")
        branches_df[!, "Positive flow at the limit"] = results.shadow_prices["NegativeFlowAtMax"]
    end
    if in_keys(results.shadow_prices, "PositiveFlowAtMax")
        branches_df[!, "Negative flow at the limit"] = results.shadow_prices["PositiveFlowAtMax"]
    end

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
    
    if in_keys(results.shadow_prices, "MarginalCostPerBus")
        buses_df[!, "Marginal cost (\$/MW)"] = results.shadow_prices["MarginalCostPerBus"]/Sb
    end
    return buses_df
end

function write_generation_results(inputs::DCOPFInputs, results::DCOPFResults)
    last_it = maximum(keys(results.solution_quality.solver_time))
    Sb = inputs.power_base
    generation_df = DataFrame(
        "Bus" => inputs.generators.bus_id,
        "Power Cost" => inputs.generators.cost[:, 1],
        "On Cost" => inputs.generators.cost[:, 2],
        "Min Generation (MW)" => inputs.generators.min_generation * Sb,
        "Max Generation (MW)" => inputs.generators.max_generation * Sb,
        "Generation (MW)" => results.var["Generation", last_it] * Sb,
    )
    return generation_df
end

function write_solution_quality(results::DCOPFResults)
    last_it = maximum(keys(results.solution_quality.solver_time))
    iteration = zeros(Int, last_it)
    time = zeros(last_it)
    obj_val = zeros(last_it)
    for i in 1:last_it
        time[i] = results.solution_quality.solver_time[i]
        obj_val[i] = results.solution_quality.objective_value[i]
    end
    quality_df = DataFrame(
        "Iteration" => 1:last_it,
        "Solver Time (s)" => time,
        "Objective Value" => obj_val,
    )
end

function write_all_data_frames(inputs::DCOPFInputs, results::DCOPFResults)
    branch_df = write_branch_results(inputs, results)
    bus_df = write_bus_results(inputs, results)
    gen_df = write_generation_results(inputs, results)
    quality_df = write_solution_quality(results)
    return branch_df, bus_df, gen_df, quality_df
end

function save_all_data_frames(inputs::DCOPFInputs, results::DCOPFResults, path::String)
    branch_df, bus_df, gen_df, quality_df = write_all_data_frames(inputs, results)
    CSV.write(joinpath(path, "branch.csv"), branch_df)
    CSV.write(joinpath(path, "bus.csv"), bus_df)
    CSV.write(joinpath(path, "generator.csv"), gen_df)
    CSV.write(joinpath(path, "solution_quality.csv"), quality_df)
    return nothing
end

function all_results_to_files(
    inputs::DCOPFInputs,
    model::DCOPFModel,
    results::DCOPFResults,
    results_path::String,
)
    save_all_data_frames(inputs, results, results_path)
    cut_plts = save_all_cut_plots(inputs, model, results)
    @save joinpath(results_path, "study_results.jld2") inputs model results cut_plts
    return nothing
end

function save_all_cut_plots(inputs::DCOPFInputs, model::DCOPFModel, results::DCOPFResults)
    num_branches = get_num_branches(inputs.branches)
    plts = Vector{Plots.Plot{Plots.PlotlyBackend}}(undef, num_branches)
    for b in 1:num_branches
        plts[b] = plot_cuts(inputs, model, results, b)
    end
    return plts
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
