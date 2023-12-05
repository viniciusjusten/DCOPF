function read_matpower(file::String)
    # file = joinpath(@__DIR__, "pglib-opf", "pglib_opf_case3_lmbd.m")
    f = open(file, "r+")
    file_lines = readlines(file, keep = true)

    bus_line_idx = findfirst(x -> occursin("mpc.bus", x), file_lines)
    bus_init_idx = findfirst(x -> occursin("[", x), file_lines[bus_line_idx:end])
    bus_end_idx = findfirst(x -> occursin("];", x), file_lines[bus_line_idx:end, :])
    bus_lines = file_lines[CartesianIndex(bus_line_idx+1, 1):CartesianIndex(bus_line_idx-2, 0)+bus_end_idx]

    branch_line_idx = findfirst(x -> occursin("mpc.branch", x), file_lines)
    branch_init_idx = findfirst(x -> occursin("[", x), file_lines[branch_line_idx:end])
    branch_end_idx = findfirst(x -> occursin("];", x), file_lines[branch_line_idx:end, :])
    branch_lines = file_lines[CartesianIndex(branch_line_idx+1, 1):CartesianIndex(branch_line_idx-2, 0)+branch_end_idx]

    gen_line_idx = findfirst(x -> occursin("mpc.gen", x), file_lines)
    gen_init_idx = findfirst(x -> occursin("[", x), file_lines[gen_line_idx:end])
    gen_end_idx = findfirst(x -> occursin("];", x), file_lines[gen_line_idx:end, :])
    gen_lines = file_lines[CartesianIndex(gen_line_idx+1, 1):CartesianIndex(gen_line_idx-2, 0)+gen_end_idx]

    gen_cost_line_idx = findfirst(x -> occursin("mpc.gencost", x), file_lines)
    gen_cost_init_idx = findfirst(x -> occursin("[", x), file_lines[gen_cost_line_idx:end])
    gen_cost_end_idx = findfirst(x -> occursin("];", x), file_lines[gen_cost_line_idx:end, :])
    gen_cost_lines = file_lines[CartesianIndex(gen_cost_line_idx+1, 1):CartesianIndex(gen_cost_line_idx-2, 0)+gen_cost_end_idx]

    bus_ = Matrix{Float64}(undef, length(bus_lines), 13)
    for line_idx in eachindex(bus_lines)
        fixed_line = replace(bus_lines[line_idx], "\t" => "")
        fixed_line = replace(fixed_line, ";\r\n" => "")
        vec_string = split(fixed_line, " ")
        elements = filter(x -> x != "", vec_string)
        bus_numbers = parse.(Float64, elements)
        bus_[line_idx, :] = bus_numbers
    end

    branch_ = Matrix{Float64}(undef, length(branch_lines), 13)
    for line_idx in eachindex(branch_lines)
        fixed_line = replace(branch_lines[line_idx], "\t" => "")
        fixed_line = replace(fixed_line, ";\r\n" => "")
        vec_string = split(fixed_line, " ")
        elements = filter(x -> x != "", vec_string)
        branch_numbers = parse.(Float64, elements)
        branch_[line_idx, :] = branch_numbers
    end

    gen_ = Matrix{Float64}(undef, length(gen_lines), 10)
    for line_idx in eachindex(gen_lines)
        fixed_line = replace(gen_lines[line_idx], "\t" => "")
        fixed_line = replace(fixed_line, ";\r\n" => "")
        fixed_line = replace(fixed_line, "; % NUC" => "")
        fixed_line = replace(fixed_line, "; % PEL" => "")
        fixed_line = replace(fixed_line, "; % COW" => "")
        fixed_line = replace(fixed_line, "; % SYNC" => "")
        fixed_line = replace(fixed_line, "; % NG" => "")
        vec_string = split(fixed_line, " ")
        elements = filter(x -> x != "", vec_string)
        gen_numbers = parse.(Float64, elements)
        gen_[line_idx, :] = gen_numbers[1:10]
    end

    gen_cost_ = Matrix{Float64}(undef, length(gen_cost_lines), 7)
    for line_idx in eachindex(gen_cost_lines)
        fixed_line = replace(gen_cost_lines[line_idx], "\t" => "")
        fixed_line = replace(fixed_line, ";\r\n" => "")
        fixed_line = replace(fixed_line, "; % NUC" => "")
        fixed_line = replace(fixed_line, "; % PEL" => "")
        fixed_line = replace(fixed_line, "; % COW" => "")
        fixed_line = replace(fixed_line, "; % SYNC" => "")
        fixed_line = replace(fixed_line, "; % NG" => "")
        vec_string = split(fixed_line, " ")
        elements = filter(x -> x != "", vec_string)
        gen_cost_numbers = parse.(Float64, elements)
        gen_cost_[line_idx, :] = gen_cost_numbers
    end

    return bus_, branch_, gen_, gen_cost_
end

function matpower_to_inputs!(
    matpower_file::String,
    inputs::DCOPFInputs,
)
    bus_, branch_, gen_, gen_cost_ = read_matpower(matpower_file)

    power_base = inputs.power_base

    inputs.buses.id = Int.(bus_[:, 1])
    inputs.buses.type = Int.(bus_[:, 2])
    inputs.buses.active_demand = bus_[:, 3]/power_base

    inputs.branches.bus_from = Int.(branch_[:, 1])
    inputs.branches.bus_to = Int.(branch_[:, 2])
    inputs.branches.resistance = branch_[:, 3]
    inputs.branches.reactance = branch_[:, 4]
    inputs.branches.max_flow = branch_[:, 6]/power_base

    inputs.generators.min_generation = gen_[:, 10]/power_base
    inputs.generators.max_generation = gen_[:, 9]/power_base
    inputs.generators.cost = gen_cost_[:, 6]
    inputs.generators.bus_id = Int.(gen_[:, 1])

    return nothing
end
