"""
    Main function for the AC power flow
"""

push!(LOAD_PATH, pwd()*"/src/")
include(pwd()*"/data/case118.jl")
include(pwd()*"/data/case33bw.jl")
include(pwd()*"/data/case9.jl")

using PowerFlow
using MATLAB
using Base.Threads

opt = PowerFlow.options() # The initial settings 
opt["PF"]["NR_ALG"] = "bicgstab";
opt["PF"]["ENFORCE_Q_LIMS"] = 0;
opt["PF"]["DC_PREPROCESS"] = 1;
#test find_islands and delete island
# mpc = case9();
mat"addpath('C:/Users/DELL/Desktop/matpower8.0/data')"
mpc = mat"case1888rte"

println("使用 $(Threads.nthreads()) 个线程进行计算")
mpc_list, isolated = PowerFlow.dc_preprocess(mpc, opt)

n_islands = length(mpc_list)
println("共提取出 $(n_islands) 个孤岛")

println("开始多线程潮流计算...")
t_start = time()

results_array = Vector{Any}(undef, n_islands)
@threads for i in 1:n_islands
    results_array[i] = PowerFlow.runpf(mpc_list[i], opt)
end

t_end = time()
elapsed = t_end - t_start

# 构造类似@timed返回的结果
results = (value=results_array, time=elapsed)
println("计算完成，耗时: $(results.time) 秒")

PowerFlow.process_result(results, isolated, "powerflow_report.txt")