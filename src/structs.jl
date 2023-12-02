Base.@kwdef mutable struct DCOPFModel
    optimizer::JuMP.Model = Model()
    var::Dict{String, Any} = Dict{String, Any}()
    con::Dict{String, Any} = Dict{String, Any}()
    expr::Dict{String, Any} = Dict{String, Any}()
    cuts::Dict{Tuple{String, Int}, Any} = Dict{Tuple{String, Int}, Any}()
    obj_exp::JuMP.AffExpr = zero(JuMP.AffExpr)
end

Base.@kwdef mutable struct DCOPFBuses
    id::Vector{Int} = Int[]
    type::Vector{Int} = Int[]
    active_demand::Vector{Float64} = Float64[]
end

Base.@kwdef mutable struct DCOPFBranches
    bus_from::Vector{Int} = Int[]
    bus_to::Vector{Int} = Int[]
    resistance::Vector{Float64} = Float64[]
    reactance::Vector{Float64} = Float64[]
    max_flow::Vector{Float64} = Float64[]
end

Base.@kwdef mutable struct DCOPFGenerators
    min_generation::Vector{Float64} = Float64[]
    max_generation::Vector{Float64} = Float64[]
    cost::Vector{Float64} = Float64[]
    bus_id::Vector{Int} = Int[]
end

Base.@kwdef mutable struct DCOPFInputs
    buses::DCOPFBuses = DCOPFBuses()
    branches::DCOPFBranches = DCOPFBranches()
    generators::DCOPFGenerators = DCOPFGenerators()
    power_base::Float64 = 100.0
    consider_losses::Bool = false
    linearize_loss::Bool = false
    max_iteration::Int = 1
    tolerance::Float64 = 1e-4
end

Base.@kwdef mutable struct SolutionQuality
    solver_time::Dict{Int, Float64} = Dict{Int, Float64}()
    gap::Dict{Int, Float64} = Dict{Int, Float64}()
    objective_value::Dict{Int, Float64} = Dict{Int, Float64}()
end

Base.@kwdef mutable struct DCOPFResults
    # tuple is name and iteration
    var::Dict{Tuple{String, Float64}, Any} = Dict{Tuple{String, Float64}, Any}()
    expr::Dict{Tuple{String, Float64}, Any} = Dict{Tuple{String, Float64}, Any}()
    obj_exp::JuMP.AffExpr = zero(JuMP.AffExpr)
    solution_quality::SolutionQuality = SolutionQuality()
end
