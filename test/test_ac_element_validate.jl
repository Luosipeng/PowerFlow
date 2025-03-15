push!(LOAD_PATH, pwd()*"/src/")
include(pwd()*"/data/case118.jl")
include(pwd()*"/data/case33bw.jl")
include(pwd()*"/data/case_reliability.jl")

using PowerFlow
# using MATLAB
using Base.Threads
using Plots

opt = PowerFlow.options() # The initial settings 
opt["PF"]["NR_ALG"] = "\\";
opt["PF"]["ENFORCE_Q_LIMS"] = 0;
opt["PF"]["DC_PREPROCESS"] = 1;
#ETAP ac system parameters file path
# file_path = "C:/Users/13733/Desktop/model_test/transformer_test/transformer_data.xlsx"
file_path = "C:/Users/13733/Desktop/model_test/cable_test/cable_data.xlsx"
# file_path = "C:/Users/13733/Desktop/model_test/xline_test/xline_data.xlsx"
# file_path = "C:/Users/13733/Desktop/model_test/impedance_test/impedance_data.xlsx"
#Process the ac system data
mpc, dict_bus, node_mapping, pv_curves = PowerFlow.excel2jpc(file_path)
mpc=PowerFlow.runpf(mpc,opt)
# result_path = "C:/Users/13733/Desktop/model_test/transformer_test/transformer_result.xlsx"
result_path = "C:/Users/13733/Desktop/model_test/cable_test/cable_result.xlsx"
# result_path = "C:/Users/13733/Desktop/model_test/xline_test/xline_result.xlsx"
# result_path = "C:/Users/13733/Desktop/model_test/impedance_test/impedance_result.xlsx"
PowerFlow.ac_element_validate("LUMPLOAD","MW",dict_bus,node_mapping,result_path,opt,mpc,connectedname=2)
