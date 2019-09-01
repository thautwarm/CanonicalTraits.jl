using CanonicalTraits
using Test

@trait Monoid{A} begin
    mempty :: [] => A
    (⊕)    :: [A, A] => A
end

const int_monoid = instance(Monoid)(() -> 0::Int, +)
const vect_monoid(::Type{T}) where T = instance(Monoid)(() -> T[], vcat)

Monoid(it) = default_monoid
Monoid(::Type{Int}) = int_monoid
Monoid(::Type{Vector{T}}) where T = vect_monoid(T)

@trait ToString{A} begin # like Show in Haskell
    to_str :: A => String
end

const default_to_string = instance(ToString)(Base.string)
ToString(it) = default_to_string

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
    vec_add    :: [V, V] => V
    scalar_add :: [F, V] => V
end

vect_infer_helper(::Type{Poly{T}}) where T = T
const polynomial_vect = instance(Vect)(
    function polynomial_scalar_mul(num::F, vec::Poly{F}) where F <: Number
        num * vec
    end,
    function polynomial_vec_add(vec1 :: Poly{F}, vec2 :: Poly{F}) where F <: Number
        vec1 + vec2
    end,
    function polynomial_scalar_add(scalar::F, vec::Poly{F}) where F <: Number
        scalar + vec
    end
)

Vect(::Type{F}, ::Type{Poly{F}}) where F <: Number = polynomial_vect

@trait Dot{F, V} where {F = vect_infer_helper(V)} begin
    dot :: [V, V] => F
    gram_schmidt :: [V, Set{V}] => V
end


function poly_dot(v1 :: Poly{F}, v2 :: Poly{F})::Real where F <: Number
        f = polyint(v1 * v2)
        f(1) - f(-1)
end
function poly_gram_schmidt(v :: Poly{F}, vs :: Set{Poly{F}})::Poly{F} where F <: Number
    for other in vs
        coef = dot(v, other) / dot(other, other)
        v -= scalar_mul(coef, other)
    end
    scalar_mul(one(F)/sqrt(dot(v, v)), v)
end

const polynomial_dot = instance(Dot)(
    poly_dot,
    poly_gram_schmidt
)

Dot(::Type{F}, ::Type{Poly{F}}) where F <: Number = polynomial_dot

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
