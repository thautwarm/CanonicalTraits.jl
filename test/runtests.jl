using CanonicalTraits
using Test

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


@trait Dot{F, V} where {F = vect_infer_helper(V)} begin
    dot :: [V, V] => F
    gram_schmidt :: [V, Set{V}] => V
end

@implement Dot{F, Poly{F}} where F <: Number begin
    function dot(v1 :: Poly{F}, v2 :: Poly{F})::Real where F <: Number
            f = polyint(v1 * v2)
            f(1) - f(-1)
    end
    function gram_schmidt(v :: Poly{F}, vs :: Set{Poly{F}})::Poly{F} where F <: Number
        for other in vs
            coef = dot(v, other) / dot(other, other)
            v = vec_sub(v, scalar_mul(coef, other))
        end
        scalar_div(v, sqrt(dot(v, v)))
    end
end

@testset "polynomial orthogonalization" begin

    @test scalar_add(5.0, Poly([2.0, 1.0])) == Poly([7.0, 1.0])
    fx1 = Poly([1.0])
    fx2 = Poly([0.0, 1.0])
    T = typeof(fx1)
    fx1_ot = gram_schmidt(fx1, Set(T[]))
    fx2_ot = gram_schmidt(fx2, Set([fx1_ot]))

    @test dot(fx1_ot, fx2_ot) ≈ 0
    @test dot(fx1_ot, fx1_ot) ≈ 1
    @test dot(fx2_ot, fx2_ot) ≈ 1

end
