function mk_method(
    trait     :: Any,
    interface :: MethodInterface,
    syms      :: Syms,
    fn_deps   :: Exprs = Expr[]
) where {Syms <: AbstractArray{Symbol}, Exprs <: AbstractArray{Expr}}
    argsty  = interface.argsty
    retty   = interface.retty
    f       = interface.name
    foralls = Any[]
    argsty  = extract_forall!(argsty, foralls)
    @when let :($tp{$(argtys...)}) = argsty,
              (tp === Tuple).?

        basename = gensym(string(f))
        argnames = [Symbol(basename, i) for i in 1:length(argtys)]
        annos    = [:($argname :: $argty) for (argname, argty) in zip(argnames, argtys)]
        quote
            function $f($(annos...)) where {$(syms...), $(foralls...)}
                let $(fn_deps...)
                    ($trait($(syms...)).$f($(argnames...)))::$retty
                end
            end
        end
    @otherwise
        error("Malformed method $f($argsty) for trait $trait.")
    end
end

function mk_default_impl(tparams::TypeParams, default_method :: DefaultMethod)
    mk_name = Symbol("mk.", default_method.name)
    mkfn   = quote
        $mk_name($(tparams.as_arguments...)) where {$(tparams.as_where...)} = $(default_method.impl)
    end
    (default_method.name, mk_name, mkfn)
end

mk_trait(syms::Syms) where Syms <: AbstractArray{Symbol} =
    @match syms begin
    [] => TraitParamNil
    [hd, tl...] => :($TraitParamCons{$hd, $(mk_trait(tl))})
    end

"""
get_instance_type
"""
function instance end
function implement end
function default_method_maker(trait, n)
    @assert n isa Val
    f(::Val{n}) where n = n
    error("No default method $(f(n)) for $trait.")
end

function trait(@nospecialize(sig), @nospecialize(block))
    fn_deps = Expr[]
    @when :($hd where {$(args...)}) = sig begin
        sig = hd
        if !isempty(args)
            fn_deps = map(args) do arg
                @when :($_ = $_) = arg begin
                    arg
                @otherwise
                    error("Malform functional dependency $arg for trait $sig.")
                end
            end
        end
    end
    @when let :($trait_ty{$(tvars...)}) = sig,
              Expr(:block, stmts...)    = block

        tsyms         = map(extract_tvars, tvars)
        tparams       = TypeParams(tsyms)
        methods       = map(extract_method, stmts)
        methods       = filter(x -> !(x isa LineNumberNode), methods)
        interfaces    = filter(x -> x isa MethodInterface, methods)
        default_impls = filter(x -> x isa DefaultMethod, methods)

        cg_interfaces   = [mk_method(trait_ty, method_interface, tsyms, fn_deps)
                           for method_interface in interfaces]

        instance_name   = Symbol(string(trait_ty), "#instance")
        interface_names = map(interfaces) do x; x.name end
        method_types    = map(x -> Symbol(x, "#t"), interface_names)
        cg_fields       = [:($a :: $b) for (a, b) in zip(interface_names, method_types)]

        (make_default_makers,  ask_default_makers) =
            let triples = map(x -> mk_default_impl(tparams, x), default_impls)
                map(x->x[3], triples),
                map(triples) do (default_name, default_maker_name, _)
                    quote
                        $CanonicalTraits.default_method_maker(
                            ::Type{$trait_ty},
                            ::Val{$(QuoteNode(default_name))}
                        ) = $default_maker_name
                    end
                end

            end
        quote
            abstract type $sig <: $Trait{$(mk_trait(tsyms))} end
            struct $instance_name{$(method_types...)}
                $(cg_fields...)
            end
            $CanonicalTraits.instance(::Type{$trait_ty}) = $instance_name
            $(cg_interfaces...)
            $(make_default_makers...)
            $(ask_default_makers...)
        end
    @otherwise
        error("Malformed trait $sig definition.")
    end
end

macro trait(@nospecialize(sig), block=Expr(:block))
    trait(sig, block) |> esc
end

(trait::Type{<:Trait})(types...) = begin
    types = join(map(string, types), ", ")
    error("Not implemented trait $trait for ($types).")
end
