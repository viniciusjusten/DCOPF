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
        if element in k
            return true
        end
    end
    return false
end
