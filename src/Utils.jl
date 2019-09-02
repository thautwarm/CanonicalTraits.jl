abstract type TraitParam end

abstract type TraitParamCons{A, B<:TraitParam} <: TraitParam
end

abstract type TraitParamNil <: TraitParam
end

abstract type Trait{P <: TraitParam} end

abstract type TraitInstance end

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


extract_method(stmt::Union{Expr, LineNumberNode})::ClassMethod =
    @match stmt begin
        :($f :: [$(args...)] => $ret) => MethodInterface(f, function_sig(:[$(args...)]),  function_sig(ret))
        :($f :: $arg => $ret)         => MethodInterface(f, function_sig(:[$arg]),  function_sig(ret))
        ::LineNumberNode              => stmt
        _                             => begin
            def = extract_default(stmt)
            def === nothing && error("Malformed method interface or default method $stmt.")
            DefaultMethod(def[1], def[2])
        end
    end

function_sig(sig) =
    @match sig begin
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

struct TypeParams
    as_arguments  :: Vector{Expr}
    as_where      :: Vector{Symbol}
end
TypeParams(syms :: Syms) where Syms <: AbstractArray{Symbol} =
    TypeParams(
       [:(::Type{$sym}) for sym in syms],
       syms
    )
