
"""
    UnitSimplexOracle(right_side)

Represents the scaled unit simplex:
```
C = {x ∈ R^n_+, ∑x ≤ right_side}
```
"""
struct UnitSimplexOracle{T} <: LinearMinimizationOracle
    right_side::T
end

UnitSimplexOracle{T}() where {T} = UnitSimplexOracle{T}(one(T))

UnitSimplexOracle(rhs::Integer) = UnitSimplexOracle{Rational{BigInt}}(rhs)

"""
LMO for scaled unit simplex.
Returns either vector of zeros or vector with one active value equal to RHS if
there exists an improving direction.
"""
function compute_extreme_point(lmo::UnitSimplexOracle{T}, direction) where {T}
    idx = argmin(direction)
    if direction[idx] < 0
        return MaybeHotVector(lmo.right_side, idx, length(direction))
    end
    return MaybeHotVector(zero(T), idx, length(direction))
end

"""
Dual costs for a given primal solution to form a primal dual pair
for scaled unit simplex.
Returns two vectors. The first one is the dual costs associated with the constraints 
and the second is the reduced costs for the variables.
"""
function compute_dual_solution(lmo::UnitSimplexOracle{T}, direction, primalSolution) where {T}
    idx = argmax(primalSolution)
    critical = min(direction[idx],0)
    lambda = [ critical ]
    mu = direction .- lambda
    return lambda, mu
end



"""
    ProbabilitySimplexOracle(right_side)

Represents the scaled probability simplex:
```
C = {x ∈ R^n_+, ∑x = right_side}
```
"""
struct ProbabilitySimplexOracle{T} <: LinearMinimizationOracle
    right_side::T
end

ProbabilitySimplexOracle{T}() where {T} = ProbabilitySimplexOracle{T}(one(T))

ProbabilitySimplexOracle(rhs::Integer) = ProbabilitySimplexOracle{Float64}(rhs)

"""
LMO for scaled probability simplex.
Returns a vector with one active value equal to RHS in the
most improving (or least degrading) direction.
"""
function compute_extreme_point(lmo::ProbabilitySimplexOracle{T}, direction) where {T}
    idx = argmin(direction)
    return MaybeHotVector(lmo.right_side, idx, length(direction))
end

"""
Dual costs for a given primal solution to form a primal dual pair
for scaled probability simplex.
Returns two vectors. The first one is the dual costs associated with the constraints 
and the second is the reduced costs for the variables.
"""
function compute_dual_solution(lmo::ProbabilitySimplexOracle{T}, direction, primalSolution) where {T}
    idx = argmax(primalSolution)
    lambda = [ direction[idx] ]
    mu = direction .- lambda
    return lambda, mu
end