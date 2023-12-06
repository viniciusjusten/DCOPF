function variableref(args...)
    return Array{JuMP.VariableRef, length(args)}(undef, args...)
end
function constraintref(args...)
    return Array{JuMP.ConstraintRef, length(args)}(undef, args...)
end
function expressionref(args...)
    return Array{JuMP.AffExpr, length(args)}(undef, args...)
end

function in_keys(dict::Dict, element::Any)
    for k in keys(dict)
        if occursin(element, k)
            return true
        end
    end
    return false
end

function any_binary(model::DCOPFModel)
    for (k, vars) in model.var
        for var in vars
            if is_binary(var)
                return true
            end
        end
    end
    return false
end
