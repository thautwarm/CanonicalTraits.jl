# CanonicalTraits.jl

```@index
```

## Features

1. [Zero-cost](#Zero-cost) abstractions(via `@implement!`)
2. Multiple-param traits
3. Functional dependencies
4. Implemented via dictionay passing algorithm
5. Elegant notations
6. Flexible Instances & Flexible Classes

## Trait Definition

```julia
@trait Addable{L, R} begin
    (+) :: [L, R] => Any
    (+) = Base.:+
end
```

Above code gives a naive implementation of `+`.

`(+) :: [L, R] => Any` says `(+)` is a function that takes 2 arguments typed `L` and `R`, and return an `Any`.

`(+) = Base.:+` says `+` has a default implementation `Base.:+`.


Note, the form `@trait A{B, C, D <: Number, E <: AbstractString}` is supported as well.

## Implementation

If all methods have a default implementation, you can do

```julia
@implement Addable{Int, Int}
```

Otherwise, if there's such a trait

```julia
@trait Show{A} begin
   show :: A => String
end
```

We'll have

```julia-repl
julia> @implement Show{Int}
ERROR: LoadError: No default method show for Show.

julia> @implement Show{Int} begin
    show(x) = string(x)
end

julia> show(114514)
"114514"
```

## Functional Dependency

This is an example of defining Vector-like traits,

```julia
function vect_eltype_infer end
@trait Vect{F, V} where {F = vect_infer_helper(V)} begin
    scalar_mul :: [F, V] => V
    scalar_div :: [V, F] => V

    vec_add    :: [V, V] => V
    vec_sub    :: [V, V] => V

    scalar_add :: [F, V] => V
    scalar_sub :: [V, F] => V

    scalar_div(vec :: V, scalar :: F) = scalar_mul(one(F)/scalar, vec)
    scalar_sub(vec :: V, scalar :: F) = scalar_add(-scalar, vec)
    vec_sub(vec1 :: V, vec2 :: V)     = vec_add(vec1, scalar_mul(-one(F), vec2))
end
```

Note that, for some methods of `Vect`, we cannot infer out the type `F` with their argument types:

```julia
vec_add    :: [V, V] => V
vec_sub    :: [V, V] => V
```

However, for instance, we know,
- when `V`  is `Vector{T}`, `V` is `T`.
- when `V` is `NTuple{5, T}`, `V` is `T`
- etc.

This is called functional dependency, and to work with this, we provide the capability of using this, check the head of the definition of `Vect`:

```julia
@trait Vect{F, V} where {F = vect_infer_helper(V)} begin
```

Which means that `F` is decided by `V` with `vect_infer_helper`.

This is an example of making `Tuple{F, F}` Vector-like:

```julia
vect_infer_helper(::Type{Tuple{F, F}}) where F<:Number = F

@implement Vect{F, Tuple{F, F}} where F <: Number begin
    scalar_add(num, vec) =
        (vec[1] + num, vec[2] + num)
    vec_add(vec1, vec2) =
        (vec1[1] + vec2[1], vec1[2] + vec2[2])
    scalar_mul(num, vec) =
        (num * vec[1], num * vec[2])
end
```

## Flexible Instances & Flexible Classes

```julia
@trait Add1{T <: Number} begin
    add1 :: [T] => T
end
@trait Add1{T} >: Addn{T <: Number} begin
    addn :: [Int, T] => T
    addn(n, x) = let s = x; for i in 1:n; s = add1(s) end; s; end
end

@implement Add1{Int} begin
    add1(x) = x + 1
end
@implement Addn{Int}
@implement! Add1{T} >: Add1{Vector{T}} where T begin
    add1(xs) = add1.(xs)
end
```

Then we can use them this way:

```julia-repl
julia> add1([1])
1-element Array{Int64,1}:
 2

julia> add1(1)
2

julia> addn(5, 1)
6

julia> addn(5, 1.2)
ERROR: Not implemented trait Add1 for (Float64).

julia> add1([1.2])
ERROR: Not implemented trait Add1 for (Float64).
```

## Use Case from An Example: Gram-Schmidt Orthogonalization

Traits manage constraints, making the constraints reasonable and decoupling implementations.

In the late 2019, a friend of mine, Yingbo,
asked me if traits can help writing orthogonalizations, because he is working for projects about JuliaDiffEq.


After pondering for some time, I made a trait-based design for Gram-Schmidt orthogonalization.

I tidied up the logic in this way:

1. `Gram-Schmidt orthogonalization` is defined in an **inner product space**.
2. An inner product space derives a trait, I call it `InnerProduct`.
3. An inner prduct space is a vector space, with an additional structure called an inner product, which tells that we need a **vector space**.
4. A vector space, a.k.a linear space, given a set of scalar numbers `F`, it is a carrier set `V` occupied with following operations, and we make a trait `Vect` for the vector space:
    - vector addition: `+ : V × V → V`
    - scalar multiplication: `* : F × V → V`  
    
Now, we could use `CanonicalTraits.jl` to transform above mathematical hierarchy into elegant Julia codes:

```julia
function scalartype_of_vectorspace end
@trait Vect{F <: Number, V} where
    {F = scalartype_of_vectorspace(V)} begin
   vec_add    :: [V, V] => V
   scalar_mul :: [F, V] => V
end

@trait InnerProduct{F <: Number, V} where 
    {F = scalartype_of_vectorspace(V)} begin
    dot :: [V, V] => F
end
```

Then we can implement Gram-Schmidt orthogonalization,

```julia
function gram_schmidt!(v :: V, vs :: Vector{V})::V where V
    for other in vs
        coef = dot(v, other) / dot(other, other)
        incr = scalar_mul(-coef, other)
        v = vec_add(v, incr)
    end
    magnitude = sqrt(dot(v, v))
    scalar_mul(1/magnitude, v)
end
```

`gram_schmidt!(a, [b, c, d])` will Gram-Schmidt orthogonalize `a` with `b, c, d`.

Now, other than a clean implementation, another advantage of using traits comes out:

```julia
julia> gram_schmidt!([1.0, 1, 1], [[1.0, 0, 0], [0, 1.0, 0]])
ERROR: MethodError: no method matching scalartype_of_vectorspace(::Type{Array{Float64,1}})
```

Okay, we want to use `gram_schmidt!` on `Vector{Float64}`, but we have to implement `scalartype_of_vectorspace` first.

So we just say the scalar set is the real numbers"

```julia
julia> scalartype_of_vectorspace(::Type{Vector{Float64}}) = Real

julia> gram_schmidt!([1.0, 1, 1], [[1.0, 0, 0], [0, 1.0, 0]])
ERROR: Not implemented trait InnerProduct for (Real, Array{Float64,1}).
```

Okay, we should implement `InnerProduct{Real, Vector{Float64}}`.

```julia
julia> @implement! InnerProduct{T, Vector{Float64}} where T <: Real begin
           dot(a, b) = sum([ai*bi  for (ai, bi) in zip(a, b)])
       end

julia> gram_schmidt!([1.0, 1, 1], [[1.0, 0, 0], [0, 1.0, 0]])
ERROR: Not implemented trait Vect for (Float64, Array{Float64,1}).
```

Okay, we implement `Vect{Real, Vector{Float64}}`.

```julia
julia> @implement! Vect{T, Vector{Float64}} where T <: Real begin
        vec_add(x, y) = Float64[xi + yi for (xi, yi) in zip(x, y)]
        scalar_mul(a, x) = Float64[(a)xi for xi in x]
    end
julia> gram_schmidt!([1.0, 1, 1], [[1.0, 0, 0], [0, 1.0, 0]])
3-element Array{Float64,1}:
 0.0
 0.0
 1.0
```

Nice.

Besides, note that `CanonicalTraits.jl` is zero-cost.

## Use Case: Modeling Algebraic Structures

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

## Zero Cost

```julia-repl
julia> using CanonicalTraits

julia> @trait Add{L, R} begin
           (+) :: [L, R] => Any
           (+) = Base.:+
       end

julia> +
+ (generic function with 1 method)

julia> @implement! Add{Int, Int}

julia> @code_native 1 + 2
	.text
; ┌ @ none within `+' @ none:0
	leaq	(%rdi,%rsi), %rax
	retq
	nopw	%cs:(%rax,%rax)
; └

julia> @code_native Base.:+(1, 2)
	.text
; ┌ @ int.jl:53 within `+'
	leaq	(%rdi,%rsi), %rax
	retq
	nopw	%cs:(%rax,%rax)
; └

julia> function vec_add(x::Vector{T}, y::Vector{T}) where T <: Number
           n = length(x)
           n !== length(y) && error("mismatch")
           s = zero(T)
           for i in 1:n
              s = Base.:+(s, @inbounds x[i] * y[i])
           end
           s
       end;

julia> eval(macroexpand(Base, :(Main.@btime $vec_add([1, 2, 3], [2, 3, 4]))))
  156.788 ns (3 allocations: 336 bytes)
3-element Array{Int64,1}:
 3
 5
 7

# `+` by hand-written
julia> @implement! Add{Vector{T}, Vector{T}} where T <: Number begin
           @inline function (+)(x, y)
              n = length(x)
              n !== length(y) && error("mismatch")
              T[xe + ye for (xe, ye) in zip(x, y)]
           end
       end

# `+` by CanonicalTraits.jl       
julia> eval(macroexpand(Base, :(Main.@btime $+([1, 2, 3], [2, 3, 4]))))
  159.861 ns (3 allocations: 336 bytes)
3-element Array{Int64,1}:
 3
 5
 7

# Standard `+` operator
julia> eval(macroexpand(Base, :(Main.@btime +([1, 2, 3], [2, 3, 4]))))
  161.955 ns (3 allocations: 336 bytes)
3-element Array{Int64,1}:
 3
 5
 7
```


## Limitations

Due to the limitations of dynamic language, the type parameters occurred in trait signature should occur in the argument of each trait methods. Also, cannot define
constants/singletons for traits because it's a technique
for static typing.

For Haskell users: `MultiParamTypeClasses` is supported. `FunctionalDependencies` is supported as well but need an explicit inference rule, like

```julia
@trait Dot{F, V} where {F = vect_infer_helper(V)} begin
    dot :: [V, V] => F
    gram_schmidt :: [V, Set{V}] => V
end
```

Cannot list out all limitations here, if any problem, please open an issue or e-mail me.
