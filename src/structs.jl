Base.@kwdef mutable struct DCOPFModel
    optimizer::JuMP.Model = Model()
    var::Dict{String, Any} = Dict{String, Any}()
    con::Dict{String, Any} = Dict{String, Any}()
    expr::Dict{String, Any} = Dict{String, Any}()
    cuts::Dict{Tuple{String, Int}, Any} = Dict{Tuple{String, Int}, Any}()
    obj_exp::JuMP.AffExpr = zero(JuMP.AffExpr)
end

Base.@kwdef mutable struct DCOPFInputs
    phase_reference::Int = 1
    Ybus::Matrix{Complex{Float64}} = Complex{Float64}[;;]
    min_flow::Matrix{Float64} = Float64[;;]
    max_flow::Matrix{Float64} = Float64[;;]
    min_generation::Vector{Float64} = Float64[]
    max_generation::Vector{Float64} = Float64[]
    generation_cost::Vector{Float64} = Float64[]
    demand::Vector{Float64} = Float64[]
    consider_losses::Bool = false
    linearize_loss::Bool = false
    max_iteration::Int = 1
    tolerance::Float64 = 1e-4
end

Base.@kwdef mutable struct DCOPFResults
    # tuple is name and iteration
    var::Dict{Tuple{String, Float64}, Any} = Dict{Tuple{String, Float64}, Any}()
    expr::Dict{Tuple{String, Float64}, Any} = Dict{Tuple{String, Float64}, Any}()
    obj_exp::JuMP.AffExpr = zero(JuMP.AffExpr)
end