module CanonicalTraits
using MLStyle

export @trait, @implement, instance

include("Utils.jl")
include("Typeclasses.jl")
include("Instances.jl")

end # module
