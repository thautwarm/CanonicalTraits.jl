# CanonicalTraits.jl

```@index
```



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

## Use Case from An Example: Gram-Schmidt Orthogonalization

Traits manage constraints, making the constraints reasonable and decoupling implementations.

In the late 2019, a friend of mine, Yinbo,
asked me if traits can help writing orthogonalizations, because he is working for projects about JuliaDiffEq.


After pondering for some time, I made a trait-based design for Gram-Schmidt orthogonalization.

I tidied up the logic in this way:

1. `Gram-Schmidt orthogonalization` is defined in an **inner product space**.

2. An inner product space derives a trait, I call it `InnerProduct`.

3. An inner prduct space is a vector space, with an additional structure called an inner product, which tells that we need a **vector space**.

4. A vector space, a.k.a linear space, given a set of scalar numbers `F`, it is a carrier set `V` occupied with these operations:
    - vector addition: `+ : V × V → V`
    - scalar multiplication: `* : F × V → V`

    Just make a trait `Vect` for the vector space.

Then we can use `CanonicalTraits.jl` to transform above mathematical hierarchy into elegant Julia codes:

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
julia> @implement InnerProduct{Real, Vector{Float64}} begin
           dot(a, b) = sum([ai*bi  for (ai, bi) in zip(a, b)])
       end

julia> gram_schmidt!([1.0, 1, 1], [[1.0, 0, 0], [0, 1.0, 0]])
ERROR: Not implemented trait Vect for (Float64, Array{Float64,1}).
```

Okay, we implement `Vect{Real, Vector{Float64}}`.

```julia
julia> @implement Vect{Real, Vector{Float64}} begin
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
