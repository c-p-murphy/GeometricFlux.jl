# GeometricFlux.jl

<p align="center">
<img width="400px" src="https://github.com/yuehhua/GeometricFlux.jl/raw/master/logos/logo.png"/>
</p>

[![Build Status](https://travis-ci.org/yuehhua/GeometricFlux.jl.svg?branch=master)](https://travis-ci.org/yuehhua/GeometricFlux.jl)
[![codecov](https://codecov.io/gh/yuehhua/GeometricFlux.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/yuehhua/GeometricFlux.jl)
[![pipeline status](https://gitlab.com/JuliaGPU/GeometricFlux-jl/badges/master/pipeline.svg)](https://gitlab.com/JuliaGPU/GeometricFlux-jl/commits/master)
[![coverage report](https://gitlab.com/JuliaGPU/GeometricFlux-jl/badges/master/coverage.svg)](https://gitlab.com/JuliaGPU/GeometricFlux-jl/commits/master)

GeometricFlux is a geometric deep learning library for [Flux](https://github.com/FluxML/Flux.jl). This library aims to be compatible with packages from [JuliaGraphs](https://github.com/JuliaGraphs) ecosystem and have support of CUDA GPU acceleration with [CuArrays](https://github.com/JuliaGPU/CuArrays.jl). Message passing scheme is implemented as a flexbile framework and fused with Graph Network block scheme. GeometricFlux is compatible with other packages that are composable with Flux.

Suggestions, issues and pull requsts are welcome.

## Installation

```
]add GeometricFlux
```

## Features

Construct layers from adjacency matrix or graph (maybe extend to other structures).
Input features (including vertex, edge or graph features) of neural network may not need a structure or type.
Labels or features for output of classification or regression are part of training data, they may not need a specific structure or type, too.

* **NOTICE**: Scatter operations on CUDA are only supported in v1.3 (due to new feature in CUDAnative v2.8 which only supports julia v1.3). CPU version scatter operations are always available.
