function converge_judge(mpc::Dict{String, Any}, file_path::String,dict_new,dict_bus)
    BUS_I=1
    bus=mpc["bus"]
    reversed_dict_new = Dict(value => key for (key, value) in dict_new)
    reversed_dict = Dict(value => key for (key, value) in dict_bus)
    busID=map(k -> reversed_dict_new[k],bus[:,BUS_I])
    bus_ID=map(k -> reversed_dict[k],busID)

    sheets_data = Dict{String, DataFrame}()

    # 打开 Excel 文件并读取工作表
    XLSX.openxlsx(file_path) do wb
        for sheet_name in XLSX.sheetnames(wb)
            sheet = XLSX.getsheet(wb, sheet_name)
            data = sheet[:]
            sheets_data[sheet_name] = DataFrame(data, :auto)
        end
    end

    IEEE_ID=sheets_data["Sheet1"][:,1]
    IEEE_voltage=sheets_data["Sheet1"][:,2]
    IEEE_angle=sheets_data["Sheet1"][:,3]

    # Create a compared dictory
    Compared_dict_voltage=Dict(IEEE_ID.=>IEEE_voltage)
    Compared_dict_angle=Dict(IEEE_ID.=>IEEE_angle)

    mpc["bus"][:,8]=map(k -> Compared_dict_voltage[k],bus_ID)
    mpc["bus"][:,9]=map(k -> Compared_dict_angle[k],bus_ID)
    return mpc
end