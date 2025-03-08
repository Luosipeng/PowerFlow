mutable struct MPC
    version::String
    baseMVA::Int
    bus::Array{Float64,2}
    gen::Array{Float64,2}
    branch::Array{Float64,2}
    gencost::Array{Float64,2}
end
