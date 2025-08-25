# Create a new JuMP model
model = Model(Gurobi.Optimizer)
function get_variables_in_objective(model::Model)
    # Get the objective function
    objective_function = JuMP.objective_function(model)
    
    # Create a set to store unique variables
    variables_in_objective = Set{JuMP.VariableRef}()
    
    function add_variable(v)
        variables_in_objective |= Set([v])
    end
    
    function add_variables_from_expression(expr)
        if expr isa JuMP.GenericAffExpr
            for term in expr.terms
                add_variable(term.second)
            end
        elseif expr isa JuMP.GenericQuadExpr
            for term in expr.terms
                add_variable(term.second.first)
                add_variable(term.second.second)
            end
        end
    end

    add_variables_from_expression(objective_function)

    return collect(variables_in_objective)
end

# Define variables
@variable(model, x)
@variable(model, y)
@variable(model, z)

# Define the objective
@objective(model, Min, 2x + 3y + z)

# Get variables in the objective
variables_in_objective = get_variables_in_objective(model)
println("Variables in the objective: ", variables_in_objective)
