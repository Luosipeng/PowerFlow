using  Dates
using  XLSX
using  DataFrames
using  Base.Threads

using  Time_Series_PowerFlow

# file_path = joinpath(pwd(), "data", "etap_runpf_acdc.xlsx")
# file_path = "C:/Users/13733/Desktop/etap-main/parameters.xlsx"
file_path = joinpath(pwd(), "data", "石桥F12草河F27未连接.xlsx")
# file_path = joinpath(pwd(), "data", "石桥F12草河F27交直流.xlsx")
load_path = joinpath(pwd(), "data", "负荷.xlsx")
price_path = joinpath(pwd(), "data", "电价.xlsx")
irradiance_path = joinpath(pwd(), "data", "辐照度.xlsx")


case = Time_Series_PowerFlow.load_julia_power_data(file_path)
time_column, time_str_column, load_names, data = Time_Series_PowerFlow.read_load_data(load_path)
time_column, time_str_column, price_profiles = Time_Series_PowerFlow.read_price_data(price_path)
time_column, time_str_column, irradiance_profiles = Time_Series_PowerFlow.read_irradiance_data(irradiance_path)

#拓扑处理

results, new_case = Time_Series_PowerFlow.topology_analysis(case, output_file="topology_results.xlsx")

empty!(new_case.storageetap)
push!(new_case.storages, Time_Series_PowerFlow.Storage(1, "Battery_ESS_1", 3, 0.75, 150, 0.3, 0.05, 0.95, 0.9, true, "lithium_ion", true))

new_case.converters[3].control_mode = "Droop_Udc_Us"
new_case.converters[2].control_mode = "Droop_Udc_Us"
new_case.converters[1].control_mode = "Droop_Udc_Us"

opt = Time_Series_PowerFlow.options() # The initial settings 
opt["PF"]["NR_ALG"] = "bicgstab";
opt["PF"]["ENFORCE_Q_LIMS"] = 0;
opt["PF"]["DC_PREPROCESS"] = 1;
opt["OPF"]["MODE"] = "Dynamic";

# 运行时序潮流计算
@time results = Time_Series_PowerFlow.runtdpf(new_case, data, load_names, price_profiles, irradiance_profiles, opt)

# 获取电压结果并绘图
Time_Series_PowerFlow.plot_voltage_time_series(results, "Bus_大刀沙村3号", new_case, 366, "AC")
# PowerFlow.plot_PD_time_series(results, "Bus_大刀沙村2号直流", case, 30, "DC")