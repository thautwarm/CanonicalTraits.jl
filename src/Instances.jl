function implement(trait::Type{<:Trait}, @nospecialize(impls), type_params :: AbstractArray, freshvars :: AbstractArray)
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
    quote
        function (::Type{$trait})($(argtypes...)) where {$(freshvars...)}
            $(cg_defs...)
            $(instance(trait))($([name_maps[mname] for mname in mnames]...))
        end
    end
end

function implement(@nospecialize(sig), @nospecialize(block), mod::Module)
    freshvars = Any[]
    @when :($trait where {$(freshvars_...)}) = sig begin
        sig = trait
        freshvars = freshvars_
    end
    @when :($trait{$(type_params...)}) = sig begin
        implement(mod.eval(trait), block, type_params, freshvars)
    @otherwise
        error("Instance should be in form of 'Trait{A, B, C, D}' instead of $sig.")

    end
end

macro implement(@nospecialize(sig), @nospecialize(block))
    implement(sig, block, __module__) |> esc
end

macro implement(@nospecialize(sig))
    implement(sig, Expr(:block), __module__) |> esc
end
