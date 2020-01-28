# CanonicalTraits

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://thautwarm.github.io/CanonicalTraits.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-purple.svg)](https://thautwarm.github.io/CanonicalTraits.jl/dev)
[![Build Status](https://travis-ci.com/thautwarm/CanonicalTraits.jl.svg?branch=master)](https://travis-ci.com/thautwarm/CanonicalTraits.jl)
[![Codecov](https://codecov.io/gh/thautwarm/CanonicalTraits.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/thautwarm/CanonicalTraits.jl)

Check documentations for more details.

## Features

1. [Zero-cost](https://thautwarm.github.io/CanonicalTraits.jl/dev/#Zero-Cost-1) abstractions(via `@implement!`)
2. Multiple-param traits
3. Functional dependencies
4. Implemented via dictionay passing algorithm
5. Elegant notations
6. Flexible Instances & Flexible Classes

```julia
"""vector space to scalar space"""
function V2F end

@trait VecSpace{F, V} where
  {F = V2F(V)} begin
   vec_add    :: [V, V] => V
   scalar_mul :: [F, V] => V
end

@trait VecSpace{F, V} >: InnerProd{F, V} where
  {F = V2F(V)} begin
  dot :: [V, V] => F
end

@trait InnerProd{F, V} >: Ortho{F, V} where
  {F = V2F(V)} begin
  gram_schmidt! :: [V, Vector{V}] => V

  gram_schmidt!(v :: V, vs :: Vector{V}) where V = begin
    for other in vs
        coef = dot(v, other) / dot(other, other)
        incr = scalar_mul(-coef, other)
        v = vec_add(v, incr)
    end
    magnitude = sqrt(dot(v, v))
    scalar_mul(1/magnitude, v)
  end
end
```
