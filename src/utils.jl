function gather(input::AbstractArray{T,N}, index::AbstractArray{<:Integer,N}, dims::Integer;
                out::AbstractArray{T,N}=similar(index, T)) where {T,N}
    @assert dims <= N "Specified dimensions must lower or equal to the rank of input matrix."

    @inbounds for x = CartesianIndices(out)
        tup = collect(Tuple(x))
        tup[dims] = index[x]
        out[x] = input[tup...]
    end
    return out
end


function gather(input::Matrix{T}, index::Array{Int}) where T
    out = Array{T}(undef, size(input,1), size(index)...)
    @inbounds for ind = CartesianIndices(index)
        out[:, ind] = input[:, index[ind]]
    end
    return out
end

identity(; kwargs...) = kwargs.data

struct GraphInfo{A,T<:Integer}
    adj::AbstractVector{A}
    edge_idx::A
    V::T
    E::T

    function GraphInfo(adj::AbstractVector{<:AbstractVector{<:Integer}})
        V = length(adj)
        edge_idx = edge_index_table(adj, V)
        E = edge_idx[end]
        new{typeof(edge_idx),typeof(V)}(adj, edge_idx, V, E)
    end
end

function edge_index_table(adj::AbstractVector{<:AbstractVector{<:Integer}},
                          N::Integer=size(adj,1))
    y = similar(adj[1], N+1)
    y .= 0, cumsum(map(length, adj))...
    y
end

## Indexing

function range_indecies(idx::Tuple)
    x = Vector{Any}(undef, length(idx))
    for (i,n) in enumerate(idx)
        x[i] = 1:n
    end
    x
end

replace_last_index!(idx::Vector, x) = (idx[end] = x; idx)

function assign!(A::AbstractArray, B::AbstractArray{T,N}; last_dim=1:size(B,N)) where {T,N}
    A_dims, B_dims = size(A), size(B)
    @assert A_dims[1:end-1] == B_dims[1:end-1] "Inconsistent dimensions with $(A_dims[1:end-1]) and $(B_dims[1:end-1])"
    A_dims = replace_last_index!(range_indecies(A_dims), last_dim)
    B_dims = range_indecies(B_dims)
    A_idxs = CartesianIndices(Tuple(A_dims))
    B_idxs = CartesianIndices(Tuple(B_dims))
    for (Aidx, Bidx) = zip(A_idxs, B_idxs)
        A[Aidx] = B[Bidx]
    end
    A
end
