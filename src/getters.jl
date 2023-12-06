### buses
function get_num_buses(buses::DCOPFBuses)
    return length(buses.id)
end
function bus_is_reference(buses::DCOPFBuses, bus_idx::Int)
    return buses.type[bus_idx] == 3
end
function get_bus_demand(buses::DCOPFBuses, bus_idx::Int)
    return buses.active_demand[bus_idx]
end
function get_bus_idx_from_bus_id(buses::DCOPFBuses, _bus_id::Int)
    return findfirst(x -> x == _bus_id, buses.id)
end

### generators
function get_num_generators(generators::DCOPFGenerators)
    return length(generators.bus_id)
end
function generators_in_bus(generators::DCOPFGenerators, _bus_id::Int)
    return findall(x -> x == _bus_id, generators.bus_id)
end
function get_min_generation(generators::DCOPFGenerators, gen_idx::Int)
    return generators.min_generation[gen_idx]
end
function get_max_generation(generators::DCOPFGenerators, gen_idx::Int)
    return generators.max_generation[gen_idx]
end
function get_generation_power_cost(generators::DCOPFGenerators, gen_idx::Int)
    return generators.cost[gen_idx, 1]
end
function get_generation_on_cost(generators::DCOPFGenerators, gen_idx::Int)
    return generators.cost[gen_idx, end]
end
function generator_has_on_cost(generators::DCOPFGenerators, gen_idx::Int)
    return get_generation_on_cost(generators, gen_idx) != 0
end

### branches
function get_num_branches(branches::DCOPFBranches)
    return length(branches.bus_from)
end
function get_conductance(branches::DCOPFBranches, branch_idx::Int)
    r = branches.resistance[branch_idx]
    x = branches.reactance[branch_idx]
    return r/(r^2 + x^2)
end
function get_reactance(branches::DCOPFBranches, branch_idx::Int)
    return branches.reactance[branch_idx]
end
function get_max_flow(branches::DCOPFBranches, branch_idx::Int)
    return branches.max_flow[branch_idx]
end
function get_bus_from(branches::DCOPFBranches, branch_idx::Int)
    return branches.bus_from[branch_idx]
end
function get_bus_to(branches::DCOPFBranches, branch_idx::Int)
    return branches.bus_to[branch_idx]
end
function get_buses_in_branch(inputs::DCOPFInputs, branch_idx::Int)
    bus_from = get_bus_idx_from_bus_id(inputs.buses, inputs.branches.bus_from[branch_idx])
    bus_to = get_bus_idx_from_bus_id(inputs.buses, inputs.branches.bus_to[branch_idx])
    return bus_from, bus_to
end
