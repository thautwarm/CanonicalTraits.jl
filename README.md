# CanonicalTraits

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://thautwarm.github.io/CanonicalTraits.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://thautwarm.github.io/CanonicalTraits.jl/dev)
[![Build Status](https://travis-ci.com/thautwarm/CanonicalTraits.jl.svg?branch=master)](https://travis-ci.com/thautwarm/CanonicalTraits.jl)
[![Codecov](https://codecov.io/gh/thautwarm/CanonicalTraits.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/thautwarm/CanonicalTraits.jl)


# Trait Definition

```julia
@trait Monoid{A} begin
    mempty :: Type{A} => A
    # a method with two arguments
    (⊕)    :: [A, A] => A
end
```

Note, the form `@trait A{B, C, D <: Number, E <: AbstractString}` is supported as well.

# Instance Definition

```julia
@implement Monoid{Int} begin
  mempty(::Type{Int}) = 0
  a ⊕ b = a + b
end


3 ⊕ 2 # 5
mempty(Int) # 0
```

# More

```julia
julia> @trait Monoid{A} begin
                  mempty :: Type{A} => A
                  # a method with two arguments
                  (⊕)    :: [A, A] => A
              end


julia> @implement Monoid{Num} where Num <: Number begin
           mempty(::Type{Num}) = zero(Num)
           (a :: Num) ⊕ (b :: Num) = a + b
       end

julia> using BenchmarkTools

julia> 3 ⊕ 2
5

julia> 3.0 ⊕ 2
ERROR: MethodError: no method matching ⊕(::Float64, ::Int64)
Closest candidates are:
  ⊕(::A, ::A) where A

julia> "" ⊕ ""
ERROR: Not implemented trait Monoid for (String).

julia> 3.0 ⊕ 2.0
5.0

julia> mempty(Int)
0

julia> mempty(Float32)
0.0f0

julia> @btime 100 ⊕ 200
  0.018 ns (0 allocations: 0 bytes)
300

julia> @btime 100 + 200
  0.018 ns (0 allocations: 0 bytes)
300
```

# Limitations

\* Due to the limitations of dynamic language, the type parameters occurred in trait signature should occur in the argument of each trait methods. Also, cannot define
constants/singletons for traits because it's a technique
for static typing.


\* For Haskell users: `MultiParamTypeClasses` is supported. `FunctionalDependencies` is supported as well but need an explicit inference rule, check [test/runtests.jl](https://github.com/thautwarm/CanonicalTraits.jl/blob/master/test/runtests.jl) and search `Dot` for more details.

```julia
@trait Dot{F, V} where {F = vect_infer_helper(V)} begin
    dot :: [V, V] => F
    gram_schmidt :: [V, Set{V}] => V
end
```



Cannot list out all limitations here, if any problem, please open an issue or e-mail me.
