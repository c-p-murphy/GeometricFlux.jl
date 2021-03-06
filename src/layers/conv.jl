const AGGR2STR = Dict{Symbol,String}(:add => "∑", :sub => "-∑", :mul => "∏", :div => "1/∏",
                                     :max => "max", :min => "min", :mean => "𝔼[]")

"""
    GCNConv(graph, in=>out)
    GCNConv(graph, in=>out, σ)

Graph convolutional layer.

# Arguments
- `graph`: should be a adjacency matrix, `SimpleGraph`, `SimpleDiGraph` (from LightGraphs) or `SimpleWeightedGraph`, `SimpleWeightedDiGraph` (from SimpleWeightedGraphs).
- `in`: the dimension of input features.
- `out`: the dimension of output features.
- `bias::Bool=true`: keyword argument, whether to learn the additive bias.

Data should be stored in (# features, # nodes) order.
For example, a 1000-node graph each node of which poses 100 feautres is constructed.
The input data would be a `1000×100` array.
"""
struct GCNConv{T,F}
    weight::AbstractMatrix{T}
    bias::AbstractMatrix{T}
    norm::AbstractMatrix{T}
    σ::F
end

function GCNConv(adj::AbstractMatrix, ch::Pair{<:Integer,<:Integer}, σ = identity;
                 init = glorot_uniform, T::DataType=Float32, bias::Bool=true)
    N = size(adj, 1)
    b = bias ? init(ch[2], N) : zeros(T, ch[2], N)
    GCNConv(init(ch[2], ch[1]), b, normalized_laplacian(adj+I, T), σ)
end

@functor GCNConv

(g::GCNConv)(X::AbstractMatrix) = g.σ.(g.weight * X * g.norm + g.bias)

function Base.show(io::IO, l::GCNConv)
    in_channel = size(l.weight, ndims(l.weight))
    out_channel = size(l.weight, ndims(l.weight)-1)
    print(io, "GCNConv(G(V=", size(l.norm, 1))
    print(io, ", E), ", in_channel, "=>", out_channel)
    l.σ == identity || print(io, ", ", l.σ)
    print(io, ")")
end



"""
    ChebConv(graph, in=>out, k)

Chebyshev spectral graph convolutional layer.

# Arguments
- `graph`: should be a adjacency matrix, `SimpleGraph`, `SimpleDiGraph` (from LightGraphs) or `SimpleWeightedGraph`, `SimpleWeightedDiGraph` (from SimpleWeightedGraphs).
- `in`: the dimension of input features.
- `out`: the dimension of output features.
- `k`: the order of Chebyshev polynomial.
- `bias::Bool=true`: keyword argument, whether to learn the additive bias.
"""
struct ChebConv{T}
    weight::AbstractArray{T,3}
    bias::AbstractMatrix{T}
    L̃::AbstractMatrix{T}
    k::Integer
    in_channel::Integer
    out_channel::Integer
end

function ChebConv(adj::AbstractMatrix, ch::Pair{<:Integer,<:Integer}, k::Integer;
                  init = glorot_uniform, T::DataType=Float32, bias::Bool=true)
    N = size(adj, 1)
    b = bias ? init(ch[2], N) : zeros(T, ch[2], N)
    L̃ = T(2. / eigmax(adj)) * normalized_laplacian(adj, T) - I
    ChebConv(init(ch[2], ch[1], k), b, L̃, k, ch[1], ch[2])
end

@functor ChebConv

function (c::ChebConv)(X::AbstractMatrix{T}) where {T<:Real}
    fin = c.in_channel
    @assert size(X, 1) == fin "Input feature size must match input channel size."
    N = size(c.L̃, 1)
    @assert size(X, 2) == N "Input vertex number must match Laplacian matrix size."
    fout = c.out_channel

    Z = similar(X, fin, N, c.k)
    Z[:,:,1] = X
    Z[:,:,2] = X * c.L̃
    for k = 3:c.k
        Z[:,:,k] = 2*view(Z, :, :, k-1)*c.L̃ - view(Z, :, :, k-2)
    end

    Y = view(c.weight, :, :, 1) * view(Z, :, :, 1)
    for k = 2:c.k
        Y += view(c.weight, :, :, k) * view(Z, :, :, k)
    end
    Y += c.bias
    return Y
end

function Base.show(io::IO, l::ChebConv)
    print(io, "ChebConv(G(V=", size(l.L̃, 1))
    print(io, ", E), ", l.in_channel, "=>", l.out_channel)
    print(io, ", k=", l.k)
    print(io, ")")
end



"""
    GraphConv(graph, in=>out)
    GraphConv(graph, in=>out, aggr)

Graph neural network layer.

# Arguments
- `graph`: should be a adjacency matrix, `SimpleGraph`, `SimpleDiGraph` (from LightGraphs) or `SimpleWeightedGraph`, `SimpleWeightedDiGraph` (from SimpleWeightedGraphs).
- `in`: the dimension of input features.
- `out`: the dimension of output features.
- `bias::Bool=true`: keyword argument, whether to learn the additive bias.
- `aggr::Symbol=:add`: an aggregate function applied to the result of message function. `:add`, `:max` and `:mean` are available.
"""
struct GraphConv{V,T} <: MessagePassing
    adjlist::V
    weight1::AbstractMatrix{T}
    weight2::AbstractMatrix{T}
    bias::AbstractMatrix{T}
    aggr::Symbol
end

function GraphConv(el::AbstractVector{<:AbstractVector{<:Integer}},
                   ch::Pair{<:Integer,<:Integer}, aggr=:add;
                   init = glorot_uniform, bias::Bool=true)
    N = size(el, 1)
    b = bias ? init(ch[2], N) : zeros(T, ch[2], N)
    GraphConv(el, init(ch[2], ch[1]), init(ch[2], ch[1]), b, aggr)
end

function GraphConv(adj::AbstractMatrix, ch::Pair{<:Integer,<:Integer}, aggr=:add;
                   init = glorot_uniform, bias::Bool=true, T::DataType=Float32)
    N = size(adj, 1)
    b = bias ? init(ch[2], N) : zeros(T, ch[2], N)
    GraphConv(neighbors(adj), init(ch[2], ch[1]), init(ch[2], ch[1]), b, aggr)
end

@functor GraphConv

message(g::GraphConv; x_i=zeros(0), x_j=zeros(0)) = g.weight2 * x_j
update(g::GraphConv; X=zeros(0), M=zeros(0)) = g.weight1*X + M + g.bias
(g::GraphConv)(X::AbstractMatrix) = propagate(g, X=X, aggr=:add)

function Base.show(io::IO, l::GraphConv)
    in_channel = size(l.weight1, ndims(l.weight1))
    out_channel = size(l.weight1, ndims(l.weight1)-1)
    print(io, "GraphConv(G(V=", length(l.adjlist), ", E=", sum(length, l.adjlist)÷2)
    print(io, "), ", in_channel, "=>", out_channel)
    print(io, ", aggr=", AGGR2STR[l.aggr])
    print(io, ")")
end



"""
    GATConv(graph, in=>out)

Graph attentional layer.

# Arguments
- `graph`: should be a adjacency matrix, `SimpleGraph`, `SimpleDiGraph` (from LightGraphs) or `SimpleWeightedGraph`, `SimpleWeightedDiGraph` (from SimpleWeightedGraphs).
- `in`: the dimension of input features.
- `out`: the dimension of output features.
- `bias::Bool=true`: keyword argument, whether to learn the additive bias.
- `negative_slope::Real=0.2`: keyword argument, the parameter of LeakyReLU.
"""
struct GATConv{V,T} <: MessagePassing
    adjlist::V
    weight::AbstractMatrix{T}
    bias::AbstractMatrix{T}
    a::AbstractArray{T,3}
    negative_slope::Real
    channel::Pair{<:Integer,<:Integer}
    heads::Integer
    concat::Bool
end

function GATConv(adj::AbstractMatrix, ch::Pair{<:Integer,<:Integer}; heads::Integer=1,
                 concat::Bool=true, negative_slope::Real=0.2, init=glorot_uniform,
                 bias::Bool=true, T::DataType=Float32)
    N = size(adj, 1)
    w = init(ch[2]*heads, ch[1])
    b = bias ? init(ch[2]*heads, N) : zeros(T, ch[2]*heads, N)
    a = init(2*ch[2], heads, 1)
    GATConv(neighbors(adj), w, b, a, negative_slope, ch, heads, concat)
end

@functor GATConv

function message(g::GATConv; x_i=zeros(0), x_j=zeros(0))
    x_i = reshape(x_i, g.channel[2], g.heads, :)
    x_j = reshape(x_j, g.channel[2], g.heads, :)
    n = size(x_j, 3)
    α = cat(repeat(x_i, outer=(1,1,n)), x_j+zero(x_j), dims=1) .* g.a
    α = reshape(sum(α, dims=1), g.heads, n)
    α = leakyrelu.(α, g.negative_slope)
    α = _softmax(α)
    x_j .*= reshape(α, 1, g.heads, n)
    reshape(x_j, g.channel[2]*g.heads, :)
end

function update(g::GATConv; X=zeros(0), M=zeros(0))
    if !g.concat
        M = mean(M, dims=2)
    end
    return M .+ g.bias
end

(g::GATConv)(X::AbstractMatrix) = propagate(g, X=g.weight*X, aggr=:add)


function _softmax(xs)
    xs = exp.(xs)
    s = sum(xs, dims=2)
    return xs ./ s
end

function Base.show(io::IO, l::GATConv)
    in_channel = size(l.weight, ndims(l.weight))
    out_channel = size(l.weight, ndims(l.weight)-1)
    print(io, "GATConv(G(V=", length(l.adjlist), ", E=", sum(length, l.adjlist)÷2)
    print(io, "), ", in_channel, "=>", out_channel)
    print(io, ", LeakyReLU(λ=", l.negative_slope)
    print(io, "))")
end



"""
    GatedGraphConv(graph, out, num_layers)

Gated graph convolution layer.

# Arguments
- `graph`: should be a adjacency matrix, `SimpleGraph`, `SimpleDiGraph` (from LightGraphs) or `SimpleWeightedGraph`, `SimpleWeightedDiGraph` (from SimpleWeightedGraphs).
- `out`: the dimension of output features.
- `num_layers` specifies the number of gated recurrent unit.
- `aggr::Symbol=:add`: an aggregate function applied to the result of message function. `:add`, `:max` and `:mean` are available.
"""
struct GatedGraphConv{V,T,R} <: MessagePassing
    adjlist::V
    weight::AbstractArray{T}
    gru::R
    out_ch::Integer
    num_layers::Integer
    aggr::Symbol
end

function GatedGraphConv(adj::AbstractMatrix, out_ch::Integer, num_layers::Integer;
                        aggr=:add, init=glorot_uniform)
    N = size(adj, 1)
    w = init(out_ch, out_ch, num_layers)
    gru = GRUCell(out_ch, out_ch)
    GatedGraphConv(neighbors(adj), w, gru, out_ch, num_layers, aggr)
end

@functor GatedGraphConv

message(g::GatedGraphConv; x_i=zeros(0), x_j=zeros(0)) = x_j
update(g::GatedGraphConv; X=zeros(0), M=zeros(0)) = M
function (g::GatedGraphConv)(X::AbstractMatrix{T}) where {T<:Real}
    H = X
    m, n = size(H)
    @assert (m <= g.out_ch) "number of input features must less or equals to output features."
    (m < g.out_ch) && (H = vcat(H, zeros(T, g.out_ch - m, n)))

    for i = 1:g.num_layers
        M = view(g.weight, :, :, i) * H
        M = propagate(g, X=M, aggr=g.aggr)
        H, _ = g.gru(H, M)
    end
    H
end

function Base.show(io::IO, l::GatedGraphConv)
    print(io, "GatedGraphConv(G(V=", length(l.adjlist), ", E=", sum(length, l.adjlist)÷2)
    print(io, "), (=>", l.out_ch)
    print(io, ")^", l.num_layers)
    print(io, ", aggr=", AGGR2STR[l.aggr])
    print(io, ")")
end



"""
    EdgeConv(graph, nn)
    EdgeConv(graph, nn, aggr)

Edge convolutional layer.

# Arguments
- `graph`: should be a adjacency matrix, `SimpleGraph`, `SimpleDiGraph` (from LightGraphs) or `SimpleWeightedGraph`, `SimpleWeightedDiGraph` (from SimpleWeightedGraphs).
- `nn`: a neural network
- `aggr::Symbol=:max`: an aggregate function applied to the result of message function. `:add`, `:max` and `:mean` are available.
"""
struct EdgeConv{V} <: MessagePassing
    adjlist::V
    nn
    aggr::Symbol
end

function EdgeConv(adj::AbstractMatrix, nn; aggr::Symbol=:max)
    EdgeConv(neighbors(adj), nn, aggr)
end

@functor EdgeConv

function message(e::EdgeConv; x_i=zeros(0), x_j=zeros(0))
    n = size(x_j, 2)
    e.nn(vcat(repeat(x_i, outer=(1,n)), x_j .- x_i))
end
update(e::EdgeConv; X=zeros(0), M=zeros(0)) = M
(e::EdgeConv)(X::AbstractMatrix) = propagate(e, X=X, aggr=e.aggr)

function Base.show(io::IO, l::EdgeConv)
    print(io, "EdgeConv(G(V=", length(l.adjlist), ", E=", sum(length, l.adjlist)÷2)
    print(io, "), ", l.nn)
    print(io, ", aggr=", AGGR2STR[l.aggr])
    print(io, ")")
end
