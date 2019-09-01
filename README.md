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
const int_monoid = instance(Monoid)((::Type{Int}) -> 0, +)
Monoid(::Type{Int}) = int_monoid

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

julia> const int_monoid = instance(Monoid)((::Type{Int}) -> 0, +)
getfield(Main, Symbol("Monoid#instance")){getfield(Main, Symbol("##3#4")),typeof(+)}(getfield(Main, Symbol("##3#4"))(), +)

julia> Monoid(::Type{Int}) = int_monoid
Monoid

julia> 3 ⊕ 2 # 5
5

julia> mempty(Int)
0

julia> "1" ⊕ "2"
ERROR: Not implemented trait Monoid for (String).
Stacktrace: ...

julia> using BenchmarkTools

julia> @btime 3 ⊕ 2
  0.018 ns (0 allocations: 0 bytes)
5

julia> @btime 3 + 2
  0.018 ns (0 allocations: 0 bytes)
5
```

# Limitations

\* Due to the limitations of dynamic language, the type parameters occurred in trait signature should occur in the argument of each trait methods. Also, cannot define
constants/singletons for traits because it's a technique
for static typing.


\* For Haskell users: `MultiParamTypeClasses` is supported, and `FunctionalDependencies` not supported yet.

Cannot list out all limitations here, if any problem, please open an issue or e-mail me.
