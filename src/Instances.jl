function implement(line::LineNumberNode,
                   constant_lookup :: Bool,
                   trait::Type{<:Trait},
                   @nospecialize(impls),
                   sup_impls   :: Vector{Expr},
                   type_params :: AbstractArray,
                   freshvars :: AbstractArray)
    mnames    = fieldnames(CanonicalTraits.instance(trait)) |> collect
    not_impls = mnames |> Set
    methods = @when Expr(:block, stmts...) = impls begin
        stmts
    @otherwise
        [impls]
    end
    defs = Pair{Symbol, Any}[]

    for i in 1:length(methods)
        push!(
            defs,
            @when (name, impl) = extract_impl(methods[i]) begin
                delete!(not_impls, name)
                name => impl
            @otherwise
                :_ => methods[i]
            end
        )
    end
    # generate default methods not implemented by user
    for mname in not_impls
        maker = default_method_maker(trait, Val(mname))
        bd    = :($maker($(type_params...)))
        push!(defs, mname => bd)
    end

    name_maps = Dict{Symbol, Symbol}()
    basename  = gensym(string(trait))

    cg_defs = map(defs) do (a, b)
        if a === :_
            b
        else
            sym = Symbol(basename, "#", a)
            name_maps[a] = sym
            :($sym = let; $b end)
        end
    end

    argtypes = [:(::Type{$tp}) for tp in type_params]
    if constant_lookup
        @q begin
            $line
            Base.@generated $line function (::Type{$trait})($(argtypes...)) where {$(freshvars...)}
                $line
                $check_inheritance($trait, $(type_params...))
                $(sup_impls...)
                $(cg_defs...)
                $(instance(trait))($([name_maps[mname] for mname in mnames]...))
            end
        end
    else
        @q begin
            $line
            function (::Type{$trait})($(argtypes...)) where {$(freshvars...)}
                $line
                $check_inheritance($trait, $(type_params...))
                $(sup_impls...)
                $(cg_defs...)
                $(instance(trait))($([name_maps[mname] for mname in mnames]...))
            end
        end
    end
end

function implement(source::LineNumberNode, constant_lookup, @nospecialize(sig), @nospecialize(block), mod::Module)
    freshvars = Any[]
    sups, sig = extract_trait_mk(sig)
    @when :($trait where {$(freshvars_...)}) = sig begin
        sig = trait
        freshvars = freshvars_
    end
    @when :($trait{$(type_params...)}) = sig begin
        implement(source, constant_lookup, mod.eval(trait), block, sups, type_params, freshvars)
    @otherwise
        error("Instance should be in form of 'Trait{A, B, C, D}' instead of '$sig'.")

    end
end

"""
If the implementation is pure static, try `@implement!` which
guarantees the constant-time instance lookup.
"""
macro implement(@nospecialize(sig), @nospecialize(block))
    implement(__source__, false, sig, block, __module__) |> esc
end

macro implement(@nospecialize(sig))
    implement(__source__, false, sig, Expr(:block), __module__) |> esc
end

"""
Implementing traits with a guarantee of constant-time instance lookup.
It's made by generated function, but once you call any methods who
belong to not yet implemented instances, you can never implement
it in this runtime.
"""
macro implement!(@nospecialize(sig), @nospecialize(block))
    implement(__source__, true, sig, block, __module__) |> esc
end

macro implement!(@nospecialize(sig))
    implement(__source__, true, sig, Expr(:block), __module__) |> esc
end
