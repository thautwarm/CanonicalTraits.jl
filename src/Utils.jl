abstract type TraitParam end

abstract type TraitParamCons{A, B<:TraitParam} <: TraitParam
end

abstract type TraitParamNil <: TraitParam
end

abstract type Trait{P <: TraitParam} end

abstract type TraitInstance end

struct MethodInterface
    name     :: Symbol
    argsty   :: Any
    retty    :: Any
    fresh    :: Vector{Any}
    infer    :: Set{Symbol} # including type class parameters inferred in callsites.
end

struct DefaultMethod
    name :: Symbol
    impl :: Expr
end
ClassMethod = Union{LineNumberNode, MethodInterface, DefaultMethod}

function extract_default(impl::LineNumberNode) end
function extract_default(@nospecialize(impl))
    function extract_default_inner(call)
        @when (:($f($(_...))) || f) && if f isa Symbol end = call begin
            f
        @when :($f :: $_) = call
            extract_default_inner(f)
        @when :($f where {$(_...)}) = call
            extract_default_inner(f)
        @otherwise
            nothing
        end
    end
    name = @match impl begin
        Expr(:function, call, _)    => extract_default_inner(call)
        Expr(:(=), call, _)         => extract_default_inner(call)
        Expr(:macrocall, _..., arg) => extract_default_inner(arg)
        _ => nothing
    end
    name === nothing && return nothing
    (name, impl)
end

function collect_default!(impl::LineNumberNode, syms :: Set{Symbol}) end
function collect_default!(@nospecialize(impl), syms :: Set{Symbol})
    found_func = extract_default(impl)
    found_func === nothing && error("Not a method definition: $impl.")
    push!(syms, found_func[1])
    nothing
end

function extract_impl(impl::LineNumberNode) end
function extract_impl(@nospecialize(impl))
    function extract_impl_inner!(call)
        @when (:($f($(_...)))) && if f isa Symbol end = call begin
            # fix mutual references when implementing interfaces.
            call.args[1] = gensym(f)
            f
        @when f::Symbol = call
            f
        @when :($f :: $_) = call
            extract_impl_inner!(f)
        @when :($f where {$(_...)}) = call
            extract_impl_inner!(f)
        @otherwise
            nothing
        end
    end
    name = @match impl begin
        Expr(:function, call, _)    => extract_impl_inner!(call)
        Expr(:(=), call, _)         => extract_impl_inner!(call)
        Expr(:macrocall, _..., arg) => extract_impl_inner!(arg)
        _ => nothing
    end
    name === nothing && return nothing
    (name, impl)
end



extract_method_interface(f::Symbol, argtys::AbstractArray, retty::Any, fresh::AbstractArray) =
    begin
    argsty = :($Tuple{$(argtys...)})
    infer  = occurred_sym(:($argsty where {$(fresh...)}))
    MethodInterface(f, argsty, retty, fresh, infer)
    end

extract_method(stmt::Union{Expr, LineNumberNode})::ClassMethod =
    @match stmt begin
        :($f :: [$(args...)] where {$(fresh...)} => $ret) => extract_method_interface(f, args, ret, fresh)
        :($f :: [$(args...)] => $ret)                     => extract_method_interface(f, args, ret, Any[])
        :($f :: $arg where {$(fresh...)} => $ret)         => extract_method_interface(f, [arg], ret, fresh)
        :($f :: $arg => $ret)                             => extract_method_interface(f, [arg], ret, Any[])
        ::LineNumberNode              => stmt
        _                             => begin
            def = extract_default(stmt)
            def === nothing && error("Malformed method interface or default method $stmt.")
            DefaultMethod(def[1], def[2])
        end
    end

extract_tvars(var :: Union{Symbol, Expr})::Symbol =
    @match var begin
        :($a <: $_) => a
        :($a >: $_) => a
        :($_ >: $a >: $_) => a
        :($_ <: $a <: $_) => a
        a::Symbol         => a
    end

struct TypeParams
    as_arguments  :: Vector{Expr}
    as_where      :: Vector{Symbol}
end

TypeParams(syms :: Syms) where Syms <: AbstractArray{Symbol} =
    TypeParams(
       [:(::Type{$sym}) for sym in syms],
       syms
    )

function occurred_sym(sig)::Set{Symbol}
    @match sig begin
        Expr(hd)              => Set(Symbol[])
        :[$(args...)]         => union!(map(occurred_sym, args)...)
        :($a where {$(b...)}) => setdiff!(occurred_sym(a), map(extract_tvars, b))
        Expr(_, tl...)        => union!(map(occurred_sym, tl)...)
        a :: Symbol           => Set([a])
        _                     => Set(Symbol[])
    end
end

function get_functional_dependency(expr)
    error("Malformed functional dependency $expr, example expected form is '{T2 = f(T1), T3 = g(T1)}'")
end
