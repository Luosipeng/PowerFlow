using  Dates
using  XLSX
using  DataFrames
using  Base.Threads
using  PowerFlow


file_path = joinpath(pwd(), "data", "test_case.xlsx")
case = PowerFlow.load_julia_power_data(file_path)

#拓扑处理

results, new_case = PowerFlow.topology_analysis(case, output_file="topology_results.xlsx")

# 查看结果
println("Found ", nrow(results["cycles"]), " cycles")
println("The network is divided into ", length(unique(results["nodes"].Partition)), " partitions")

# empty!(new_case.storageetap)
# new_case.converters[3].control_mode = "Droop_Udc_Us"
# new_case.converters[2].control_mode = "Droop_Udc_Us"
# new_case.converters[1].control_mode = "Droop_Udc_Qs"

jpc = PowerFlow.JuliaPowerCase2Jpc(new_case)

opt = PowerFlow.options() # The initial settings 
opt["PF"]["NR_ALG"] = "bicgstab";
opt["PF"]["ENFORCE_Q_LIMS"] = 0;
opt["PF"]["DC_PREPROCESS"] = 1;

jpc_list, isolated = PowerFlow.extract_islands_acdc(jpc)
n_islands = length(jpc_list)
println("extract $(n_islands) islands from the case")

# create an array to store results for each island
results_array = Vector{Any}(undef, n_islands)

println("start calculating...")
t_start = time()

# using multiple threads to run power flow calculations on each island
@threads for i in 1:n_islands
    results_array[i] = PowerFlow.runhpf(jpc_list[i], opt)
end

t_end = time()
elapsed = t_end - t_start

# construct the results object
results = (value=results_array, time=elapsed)


# # obtain the bus voltage results
voltage_results = PowerFlow.get_bus_voltage_results_acdc(results, new_case)

# # 比较结果与参考文件
# result_file = joinpath(pwd(), "data", "石桥F12草河F27交直流result.xlsx")
# result_file = "C:/Users/13733/Desktop/etap-main/result.xlsx"
# PowerFlow.analyze_voltage_results(results, case, result_file, output_dir="./analysis_results")

# println("计算完成，耗时: $(results.time) 秒")
# PowerFlow.process_result(results, isolated, "powerflow_report.txt")
