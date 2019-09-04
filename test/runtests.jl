using CanonicalTraits
using Test
import LinearAlgebra

@trait Monoid{A} begin
    mempty :: Type{A} => A
    (⊕)    :: [A, A] => A
end

@implement Monoid{Int} begin
    mempty(_) = 0
    ⊕         = +
end

@implement Monoid{Vector{T}} where T begin
    mempty(_) = T[]
    ⊕         = vcat
end

@trait ToString{A} begin # like Show in Haskell
    to_str :: A => String
    to_str = Base.string # default implementation
end

@implement ToString{A} where A # for all types

# 100 ⊕ 2 |> println
# @btime 100 ⊕ 2
# @btime 100 + 2
# @btime vcat([1, 2, 3], [3, 4, 5])
# @btime [1, 2, 3] ⊕ [3, 4, 5]
# @btime 1 ⊕ 2


@testset "simple" begin
    # Write your own tests here.
    @test_throws Any begin
        "2" ⊕ "3"
    end

    @test 102 == begin
        100 ⊕ 2
    end

    @test [1, 2, 3, 3] == begin
        [1, 2] ⊕ [3, 3]
    end

    @test map(to_str, ["123", 10]) == map(string, ["123", 10])
end


using Polynomials

function vect_infer_helper
end

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

vect_infer_helper(::Type{Poly{T}}) where T = T

@implement Vect{F, Poly{F}} where F <: Number begin
    function scalar_mul(num::F, vec::Poly{F}) where F <: Number
        num * vec
    end
    function vec_add(vec1 :: Poly{F}, vec2 :: Poly{F}) where F <: Number
        vec1 + vec2
    end
    function scalar_add(scalar::F, vec::Poly{F}) where F <: Number
        scalar + vec
    end
end

@trait Dot{F <: Number, V} where {F = vect_infer_helper(V)} begin
    dot :: [V, V] => F
    gram_schmidt :: [V, Vector{V}] => V
    function gram_schmidt(v :: V, vs :: Vector{V})::V where F <: Number
        for other in vs
            coef = dot(v, other) / dot(other, other)
            v = vec_sub(v, scalar_mul(coef, other))
        end
        scalar_div(v, sqrt(dot(v, v)))
    end
end

@implement Dot{F, Poly{F}} where F <: Number begin
    function dot(v1 :: Poly{F}, v2 :: Poly{F})::Real where F <: Number
            f = polyint(v1 * v2)
            f(1) - f(-1)
    end
end

vect_infer_helper(::Type{Tuple{F, F}}) where F<:Number = F

@implement Vect{F, Tuple{F, F}} where F <: Number begin
    scalar_add(num, vec) =
        (vec[1] + num, vec[2] + num)
    vec_add(vec1, vec2) =
        (vec1[1] + vec2[1], vec1[2] + vec2[2])
    scalar_mul(num, vec) =
        (num * vec[1], num * vec[2])
end

@implement Dot{F, Tuple{F, F}} where F <: Number begin
    function dot(v1, v2)
        LinearAlgebra.dot(F[v1[1], v1[2]], F[v2[1], v2[2]])
    end
end

@testset "polynomial orthogonalization" begin

    @test scalar_add(5.0, Poly([2.0, 1.0])) == Poly([7.0, 1.0])
    fx1 = Poly([1.0])
    fx2 = Poly([0.0, 1.0])
    T = typeof(fx1)
    fx1_ot = gram_schmidt(fx1, T[])
    fx2_ot = gram_schmidt(fx2, T[fx1_ot])

    @test dot(fx1_ot, fx2_ot) ≈ 0
    @test dot(fx1_ot, fx1_ot) ≈ 1
    @test dot(fx2_ot, fx2_ot) ≈ 1

    fx1 = (1.0, 2.0)
    fx2 = (3.0, 5.0)
    T = typeof(fx1)
    fx1_ot = gram_schmidt(fx1, T[])
    fx2_ot = gram_schmidt(fx2, T[fx1_ot])

    @test dot(fx1_ot, fx2_ot) + 1.0 ≈ 1.0
    @test dot(fx1_ot, fx1_ot) ≈ 1.0
    @test dot(fx2_ot, fx2_ot) ≈ 1.0

end

using MLStyle
function type_constructor_from_hkt end
function type_argument_from_hkt end
function type_app end

# type app representation
struct App{Cons, K₀}
    injected :: Any
end

@trait Higher{Cons, K₀, K₁} where {
    Cons=type_constructor_from_hkt(K₁),
    K₀=type_argument_from_hkt(K₁),
    K₁=type_app(Cons, K₀)
} begin
    inj :: K₁ => App{Cons, K₀}
    inj(data::K₁) = App{Cons, K₀}(data)
    prj :: App{Cons, K₀} => K₁
    prj(data::App{Cons, K₀})::K₁ = data.injected
end

abstract type HKVect end
Base.@pure type_constructor_from_hkt(::Type{Vector{T}}) where T = HKVect
Base.@pure type_argument_from_hkt(::Type{Vector{T}}) where T = T
Base.@pure type_app(::Type{HKVect}, ::Type{T}) where T = Vector{T}
@implement Higher{HKVect, T, Vector{T}} where T

@testset "higher kinded" begin
    hkt_vect = inj([1, 2, 3])
    @test (hkt_vect |> typeof) == App{HKVect, Int}
    @test prj(hkt_vect) == [1, 2, 3]
end


@trait P{A} begin
    fx :: A => Int
end

@implement P{Symbol} begin
    fx(x) = 1
end

@implement P{Tuple{T, T}} where T begin
    fx(x) = fx(x[1]) + fx(x[2])
end

@testset "mutually referencing" begin
    @test fx(:a) == 1
    @test fx((:a, :b)) == 2
end