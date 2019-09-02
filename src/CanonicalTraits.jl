module CanonicalTraits
using MLStyle

export @trait, @implement, instance

struct MethodInterface
    name    :: Symbol
    argsty  :: Any
    retty   :: Any
end
struct DefaultMethod
    name :: Symbol
    impl :: Expr
end
ClassMethod = Union{LineNumberNode, MethodInterface, DefaultMethod}
include("Utils.jl")
include("Typeclasses.jl")
include("Instances.jl")

end # module
