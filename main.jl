"""
    Main function for the AC power flow
"""

push!(LOAD_PATH, pwd()*"/src/")
include(pwd()*"/data/case118.jl")
include(pwd()*"/data/case33bw.jl")
include(pwd()*"/data/case9.jl")

using PowerFlow
using MATLAB

opt = PowerFlow.options() # The initial settings 
opt["PF"]["NR_ALG"] = "bicgstab";
opt["PF"]["ENFORCE_Q_LIMS"] = 0;
opt["PF"]["DC_PREPROCESS"] = 1;
#test find_islands and delete island
# mpc = case9();
mat"addpath('C:/Users/DELL/Desktop/matpower8.0/data')"
mpc = mat"case1888rte"

mpc_list, isolated = PowerFlow.extract_islands(mpc)
# preconditioned_list = [PowerFlow.runprepf(island, opt) for island in mpc_list]
# mpc_list, isolated = PowerFlow.dc_preprocess(mpc, opt)
# #TODO:后续如果孤岛数太多，需要参考Distributed模块做分布式计算
results = @timed [PowerFlow.runpf(island, opt) for island in mpc_list]

# @time mpc = PowerFlow.runpf(mpc, opt)
# results = @timed [PowerFlow.runpf(island, opt) for island in mpc_list]
PowerFlow.process_result(results, isolated, "powerflow_report.txt")