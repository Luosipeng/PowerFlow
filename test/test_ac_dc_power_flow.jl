"""
    Main function for the AC power flow
"""

# Detect the current working operating system
if Sys.iswindows()
    # Add the path to the data folder
    push!(LOAD_PATH, pwd()*"\\src\\")
    include(pwd()*"\\data\\case3.jl")
else
    # Add the path to the data folder
    push!(LOAD_PATH, pwd()*"/src/")
    include(pwd()*"/data/case118.jl")
    using AppleAccelerate
end
# push!(LOAD_PATH, pwd()*"\\data\\");
using PowerFlow
using DataFrames
using XLSX
using Plots
opt = PowerFlow.options() # The initial settings 
opt["PF"]["NR_ALG"] = "gmres";
opt["PF"]["ENFORCE_Q_LIMS"]=0

mpc = case3()
# ACfile_path = joinpath(pwd(), "data", "etap_acparameter.xlsx")
# DCfile_path=joinpath(pwd(), "data", "etap_dcparameter.xlsx")

# mpc, dict_bus, node_mapping, pv_curves = PowerFlow.excel2jpc(ACfile_path,DCfile_path)
@time mpc = PowerFlow.runhpf(mpc, opt)

