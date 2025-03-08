function setproploop(elementtype,filed,value0,opt;connectedbus=nothing,Ftbus=nothing,Ttbus=nothing)
    x_array = []
    # bus_ID1_array = []
    # bus_ID2_array = []
    volt_mag1_array = []
    volt_mag2_array = []
    volt_ang1_array = []
    volt_ang2_array = []
    result=[]

    for i in 0:9
        file_path = "C:/Users/13733/Desktop/transformer_test.xlsx"
        mpc,dict_bus,dict_new=PowerFlow.excel2jpc(file_path)
        value=value0+0.01*i
        mpc=setloadprops(mpc,elementtype,filed,value,dict_bus,dict_new,connectedname=connectedbus,Fbus=Ftbus,Tbus=Ttbus)
        result=runpf(mpc,opt)
        append!(x_array,value)
        # reversed_dict_new = Dict(value => key for (key, value) in dict_new)
        # reversed_dict = Dict(value => key for (key, value) in dict_bus)
        # bus[:,BUS_I]=map(k -> reversed_dict_new[k],mpc.bus[:,BUS_I])
        # bus_ID=map(k -> reversed_dict[k],mpc.bus[:,BUS_I])
        # append!(bus_ID1_array,bus_ID[1])
        # append!(bus_ID2_array,bus_ID[2])
        append!(volt_mag1_array,result["bus"][1,8])
        append!(volt_mag2_array,result["bus"][2,8])
        append!(volt_ang1_array,result["bus"][1,9])
        append!(volt_ang2_array,result["bus"][2,9])
    end
        voltage=hcat(x_array,volt_mag1_array,volt_mag2_array,volt_ang1_array,volt_ang2_array)
    return result,voltage
end