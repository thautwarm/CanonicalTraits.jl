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
    to_str :: [A] => String
end

const default_to_string = instance(ToString)(Base.string)
ToString(it) = default_to_string

# using Polynomials
# @trait Vect{V, E} begin
#     coef       :: ([Num, V] where Num <: Number) => V
#     vec_add    :: ([V, V]) => V
#     scalar_add :: ([E, V]) => V
# end

# const polynomial_vect = instance(Vect)(
#     function polynomial_coef(num::Num1, vec::Poly{Num2}) where {Num1 <: Number, Num2 <: Number}
#         num * vec
#     end,
#     function polynomial_vec_add(vec1 :: Poly{Num}, vec2 :: Poly{Num}) where Num <: Number
#         vec1 + vec2
#     end,
#     function polynomial_scalar_add(scalar::Num, vec::Poly{Num}) where Num <: Number
#         scalar + vec
#     end
# )

# Vect(::Type{Poly{Num}}, ::Type{Num}) where Num <: Number = polynomial_vect


# @trait Dot{V} begin
#     dot :: [V, V] => Real
#     gram_schmidt :: [V, Set{V}] => V
# end

# const polynomial_dot = instance(Dot)(
#     function poly_dot(v1 :: Poly{Num}, v2 :: Poly{Num})::Real where Num <: Number
#         f = polyint(v1 * v2)
#         f(1) - f(-1)
#     end,
#     function poly_gram_schmidt(v :: Poly{Num}, vs :: Set{Poly{Num}})::Poly{Num} where Num <: Number
#         for other in vs
#             coeff = dot(v, other)
#         end
#     end
# )

# Dot(::Type{Poly{<:Number}}) = polynomial_dot

# 100 ⊕ 2 |> println
# @btime 100 ⊕ 2
# @btime 100 + 2
# @btime vcat([1, 2, 3], [3, 4, 5])
# @btime [1, 2, 3] ⊕ [3, 4, 5]
# @btime 1 ⊕ 2


@testset "CanonicalTraits.jl" begin
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
