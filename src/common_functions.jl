function variableref(args...)
    return Array{JuMP.VariableRef, length(args)}(undef, args...)
end
function constraintref(args...)
    return Array{JuMP.ConstraintRef, length(args)}(undef, args...)
end
function expressionref(args...)
    return Array{JuMP.AffExpr, length(args)}(undef, args...)
end

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
    return nothing
end

function in_keys(dict::Dict, element::Any)
    for k in keys(dict)
        if element in k
            return true
        end
    end
    return false
end
