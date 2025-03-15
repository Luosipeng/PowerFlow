"""
    Define the power flow module with different functions
"""

module PowerFlow
    using Printf
    using SparseArrays
    using LinearAlgebra
    using PrettyTables
    using AMD
    using SuiteSparse
    using IterativeSolvers
    using IncompleteLU
    using KrylovKit
    using Krylov
    using LinearOperators
    # using AlgebraicMultigrid
    using XLSX
    using DataFrames
    using StatsBase
    using Graphs
    using DataStructures  
    using Dates
    using Base.Threads

    using Plots
    # using KrylovPreconditioners
    # using different packages based on the operating system
    # ... 其他直接在 src 下的文件 ...
    include(joinpath(@__DIR__,"idx.jl"))
    include(joinpath(@__DIR__,"bustypes.jl"))
    include(joinpath(@__DIR__,"ext2int.jl"))
    include(joinpath(@__DIR__,"makeYbus.jl"))
    include(joinpath(@__DIR__,"newtonpf.jl"))
    include(joinpath(@__DIR__,"makeSbus.jl"))
    include(joinpath(@__DIR__,"makeSdzip.jl"))
    include(joinpath(@__DIR__,"julinsolve.jl"))
    include(joinpath(@__DIR__,"total_load.jl"))
    include(joinpath(@__DIR__,"pfsoln.jl"))
    include(joinpath(@__DIR__,"dSbus_dV.jl"))
    include(joinpath(@__DIR__,"runpf.jl"))
    include(joinpath(@__DIR__,"settings.jl"))
    include(joinpath(@__DIR__,"rundcpf.jl"))
    include(joinpath(@__DIR__,"makeBdc.jl"))
    include(joinpath(@__DIR__,"dcpf.jl"))
    include(joinpath(@__DIR__,"find_island.jl"))
    include(joinpath(@__DIR__,"int2ext.jl"))
    include(joinpath(@__DIR__,"runprepf.jl"))
    include(joinpath(@__DIR__,"dc_preprocess.jl"))
    # include(joinpath(@__DIR__,"gpu_gmres.jl"))
    include(joinpath(@__DIR__,"extract_data.jl"))
    include(joinpath(@__DIR__,"reorganized_bus_data.jl"))
    include(joinpath(@__DIR__,"reorganized_gen_data.jl"))
    include(joinpath(@__DIR__,"graph_isolated_delete.jl"))
    include(joinpath(@__DIR__,"process_branches_data.jl"))
    include(joinpath(@__DIR__,"runhpf.jl"))
    include(joinpath(@__DIR__,"dcbustypes.jl"))
    include(joinpath(@__DIR__,"newtondcpf.jl"))
    include(joinpath(@__DIR__,"dcpfsoln.jl"))
    include(joinpath(@__DIR__,"process_inverter_data.jl"))
    include(joinpath(@__DIR__,"reorganized_dcbus_data.jl"))
    include(joinpath(@__DIR__,"process_dcbranch_data.jl"))
    include(joinpath(@__DIR__,"process_topology.jl"))
    include(joinpath(@__DIR__,"process_load_data.jl"))
    include(joinpath(@__DIR__,"model_examine.jl"))
    include(joinpath(@__DIR__,"jpc_validate.jl"))
    include(joinpath(@__DIR__,"pf_summary.jl"))
    include(joinpath(@__DIR__,"extract_island.jl"))
    include(joinpath(@__DIR__,"merge_results.jl"))
    include(joinpath(@__DIR__,"process_result.jl"))
    include(joinpath(@__DIR__,"process_charger_data.jl"))
    # ... 其他 models 目录下的文件 ...
    include(joinpath(dirname(@__DIR__), "models","bus_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","gen_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","xline_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","cable_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","XFORM2W_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","utility_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","hvcb_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","load_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","dcimp_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","inverter_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","imp_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","dcbus_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","battery_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","dcload_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","charger_idx.jl"))
    include(joinpath(dirname(@__DIR__), "models","dccable_idx.jl"))
    # ... 其他 test 目录下的文件 ...
 
    include(joinpath(dirname(@__DIR__), "test","ac_element_validate.jl"))
    include(joinpath(dirname(@__DIR__), "test","dc_element_validate.jl"))
    include(joinpath(dirname(@__DIR__), "test","acdc_power_flow_compared.jl"))
    include(joinpath(dirname(@__DIR__), "test","ac_power_flow_compared.jl"))
    # include(joinpath(dirname(@__DIR__), "test","modelingexamine.jl"))
    include(joinpath(dirname(@__DIR__), "test","converge_judge.jl"))
    # ... 其他 ios 目录下的文件 ...
    include(joinpath(dirname(@__DIR__), "ios","excel2jpc.jl"))
    # ... 其他 data 目录下的文件 ...
    include(joinpath(dirname(@__DIR__), "data","case3.jl"))
    include(joinpath(dirname(@__DIR__), "data","case33bw.jl"))
    include(joinpath(dirname(@__DIR__), "data","case118.jl"))
    
    
    # include("data_structure.jl")
    # export idx_bus, idx_brch, idx_gen, bustypes, makeYbus, newtonpf, makeSbus, makeSdzip, mplinsolve, total_load, pfsoln, dSbus_dV, MPC
end

export PowerFlow