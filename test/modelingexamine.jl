using XLSX
using Plots
function modelingexamine(elementtype,field,value,opt;connectedname=nothing,Fbus=nothing,Tbus=nothing)
    result,voltage=PowerFlow.setproploop(elementtype,field,value,opt,connectedbus=connectedname,Ftbus=Fbus,Ttbus=Tbus)
        compared_path="C:/Users/13733/Desktop/etap-main/result.xlsx"
        sheets_data = Dict{String, DataFrame}()

    # 打开 Excel 文件并读取工作表
    XLSX.openxlsx(compared_path) do wb
        for sheet_name in XLSX.sheetnames(wb)
            sheet = XLSX.getsheet(wb, sheet_name)
            data = sheet[:]
            sheets_data[sheet_name] = DataFrame(data, :auto)
        end
    end
    # 提取数据
    result_reort = sheets_data["Sheet1"]

    magnitude_etap=result_reort[2:end,5]
    angle_etap=result_reort[2:end,7]

    magnitude_result=voltage[:,3]
    angle_result=voltage[:,5]

    mis_mag=magnitude_etap-magnitude_result
    mis_ang=angle_etap-angle_result
    plot(mis_mag, label="Voltage magnitude difference")
    plot!(mis_ang, label="Voltage angle difference")
end