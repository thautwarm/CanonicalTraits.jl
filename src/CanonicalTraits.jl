module CanonicalTraits
using MLStyle

export @trait, instance

abstract type TraitParam end

abstract type TraitParamCons{A, B<:TraitParam} <: TraitParam
end

abstract type TraitParamNil <: TraitParam
end

abstract type Trait{P <: TraitParam} end

abstract type TraitInstance end

struct FuncType{Args, Ret, F}
end

function_sig(sig) =
    @match sig begin
        :($arg => $ret) =>
            let arg = function_sig(arg),
                ret = function_sig(ret)
                :($FuncType{$arg, $ret})
            end
        :[$(args...)] => :($Tuple{$(map(function_sig, args)...)})
        Expr(hd, tl...) => Expr(hd, map(function_sig, tl)...)
        a => a
    end

extract_tvars(var :: Union{Symbol, Expr})::Symbol =
    @match var begin
        :($a <: $_) => a
        :($a >: $_) => a
        :($_ >: $a >: $_) => a
        :($_ <: $a <: $_) => a
        a::Symbol         => a
    end

extract_forall!(var, coll::Vector{Any}) =
    @match var begin
        :($a where {$(tvars...)}) => begin
                append!(coll, tvars)
                extract_forall!(a, coll)
            end
        Expr(hd, tl...) => Expr(hd, map(x -> extract_forall!(x, coll), tl)...)
        a => a
    end

extract_method(stmt::Union{Expr, LineNumberNode})::Union{Tuple, LineNumberNode} =
    @match stmt begin
        :($f :: $arg => $ret) => (f, function_sig(arg),  function_sig(ret))
        _            => stmt
    end

function mk_method(trait :: Any, f :: Any, argsty :: Any, retty :: Any, syms :: Syms) where Syms <: AbstractArray{Symbol}
    foralls = Any[]
    argsty  = extract_forall!(argsty, foralls)
    @when let :($tp{$(argtys...)}) = argsty,
              (tp === Tuple).?

        basename = gensym(string(f))
        argnames = [Symbol(basename, i) for i in 1:length(argtys)]
        annos    = [:($argname :: $argty) for (argname, argty) in zip(argnames, argtys)]
        quote
            function $f($(annos...))::$retty where {$(syms...), $(foralls...)}
                $trait($(syms...)).$f($(argnames...))
            end
        end
    @otherwise
        error("Malformed method $f($argsty) for trait $trait.")
    end
end

mk_trait(syms::Syms) where Syms <: AbstractArray{Symbol} =
    @match syms begin
    [] => TraitParamNil
    [hd, tl...] => :($TraitParamCons{$hd, $(mk_trait(tl))})
    end

"""
get_instance_type
"""
function instance(trait :: Type{<:Trait})
end

function trait(sig, block)
    @when let :($trait_ty{$(tvars...)}) = sig,
              Expr(:block, stmts...) = block

        tsyms      = map(extract_tvars, tvars)
        methods    = map(extract_method, stmts)
        methods    = filter(x -> !(x isa LineNumberNode), methods)
        interfaces = [mk_method(trait_ty, f, argsty, retty, tsyms)
                      for (f, argsty, retty) in methods]
        instance_   = Symbol(string(trait_ty), "#instance")
        interface_names = map(first, methods)
        method_types = map(x -> Symbol(x, "#t"), interface_names)
        fields = [:($a :: $b) for (a, b) in zip(interface_names, method_types)]

        quote
            abstract type $sig <: $Trait{$(mk_trait(tsyms))}
            end
            struct $instance_{$(method_types...)}
                $(fields...)
            end
            $(interfaces...)
            $CanonicalTraits.instance(::Type{$trait_ty}) = $instance_
        end
    @otherwise
        error("Malformed trait $sig definition.")
    end
end

macro trait(sig, block=Expr(:block))
    trait(sig, block) |> esc
end

(trait::Type{<:Trait})(types...) = begin
    types = join(map(string, types), ", ")
    error("Not implemented trait $trait for ($types).")
end

end # module
