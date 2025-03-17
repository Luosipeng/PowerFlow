# test_power_components.jl

using XLSX
using DataFrames
using Test

# 包含您之前提供的所有结构体和验证函数
# include("model_examine.jl")  # 假设您的代码保存在这个文件中

# 添加读取Excel文件的功能，只读取存在的工作表
function read_excel_data(file_path)
    xf = XLSX.readxlsx(file_path)
    sheet_names = XLSX.sheetnames(xf)
    
    # 创建一个空字典来存储数据
    data = Dict{String, DataFrame}()
    
    # 工作表名称与数据字典键的映射
    sheet_map = Dict(
        "BUS" => "bus",
        "ACCABLE" => "cable",
        "XLINE" => "transline",
        "XFORM2W" => "transformer",
        "LUMPEDLOAD" => "load",
        "UTIL" => "utility",
        "HVCB" => "hvcb",
        "DCBUS" => "dcbus",
        "DCIMPEDANCE" => "dc_impedance",
        "BATTERY" => "battery",
        "DCLOAD" => "dc_load",
        "INVERTER" => "inverter"
    )
    
    # 只读取存在的工作表
    for (sheet_name, dict_key) in sheet_map
        if sheet_name in sheet_names
            try
                data[dict_key] = DataFrame(XLSX.readtable(file_path, sheet_name))
                println("成功读取工作表: $sheet_name")
            catch e
                println("读取工作表 $sheet_name 时出错: $e")
                # 如果读取失败，创建一个空的DataFrame
                data[dict_key] = DataFrame()
            end
        else
            println("工作表 $sheet_name 不存在，已跳过")
            # 对于不存在的工作表，创建一个空的DataFrame
            data[dict_key] = DataFrame()
        end
    end
    
    return data
end

# 辅助函数：将字符串转换为布尔值
function parse_bool(value_str)
    if value_str == "1" || lowercase(value_str) == "true"
        return true
    elseif value_str == "0" || lowercase(value_str) == "false"
        return false
    else
        @warn "无法将 '$(value_str)' 解析为布尔值，使用默认值 false"
        return false
    end
end

# 测试总函数：运行所有组件测试
function run_all_component_tests(excel_path)
    # 读取Excel数据
    data = nothing
    
    @testset "电力系统组件验证测试" begin
        @testset "Excel数据读取测试" begin
            @test_nowarn begin
                data = read_excel_data(excel_path)
                # 检查是否成功读取了必需的表格
                @test haskey(data, "bus")
                @test haskey(data, "cable")
                @test haskey(data, "transline")
                @test haskey(data, "transformer")
                @test haskey(data, "load")
                @test haskey(data, "utility")
                @test haskey(data, "hvcb")
            end
        end
    end
    # 只有当数据读取成功时才继续测试
    if data !== nothing
        test_bus_components(data)
        test_cable_components(data)
        test_xline_components(data)
        # 可以在这里添加更多组件的测试
    end
    
end

# 测试Bus组件
function test_bus_components(data)
    @testset "Bus (母线) 测试" begin
        bus = data["bus"]
        
        for i in 1:nrow(bus)
            # 将字符串转换为布尔值
            in_service_bool = parse_bool(bus[i, :InService])
            
            # 测试有效参数
            @test validate_bus_parameters(
                parse(Float64, bus[i, :NominalKV]),  # vn_kv
                bus[i, :RatingType],                 # bus_type
                1.1,                                 # max_vm_pu
                0.9,                                 # min_vm_pu
                in_service_bool                      # in_service (布尔值)
            )
        end
    end
end

# 测试Cable组件
function test_cable_components(data)
    @testset "ACCable 测试" begin
        cable = data["cable"]
        
        for i in 1:nrow(cable)
            # 将字符串转换为布尔值
            in_service_bool = parse_bool(cable[i, :InService])
            
            # 测试有效参数
            @test validate_line_parameters(
                parse(Float64, cable[i, :LENGTH]),     # length_km
                parse(Float64, cable[i, :RPosValue]),  # r_ohm_per_km
                parse(Float64, cable[i, :XPosValue]),  # x_ohm_per_km
                0.0,                                   # c_nf_per_km
                parse(Float64, cable[i, :RPosValue]),  # r0_ohm_per_km
                parse(Float64, cable[i, :XPosValue]),  # x0_ohm_per_km
                0.0,                                   # c0_nf_per_km
                0.0,                                   # g_us_per_km
                1.0,                                   # max_i_ka
                1,                                     # parallel
                1.0,                                   # df_star
                "cs",                                  # line_type
                100.0,                                 # max_loading_percent
                27.5,                                  # endtemp_degree
                in_service_bool                        # in_service (布尔值)
            )
        end
    end
end

# 测试XLine组件
function test_xline_components(data)
    @testset "XLINE 测试" begin
        xline = data["transline"]
        
        for i in 1:nrow(xline)
            # 将字符串转换为布尔值
            in_service_bool = parse_bool(xline[i, :InService])
            
            # 测试有效参数
            @test validate_line_parameters(
                parse(Float64, xline[i, :LENGTH]),  # length_km
                parse(Float64, xline[i, :R1]),      # r_ohm_per_km
                parse(Float64, xline[i, :X1]),      # x_ohm_per_km
                0.0,                                # c_nf_per_km
                parse(Float64, xline[i, :R0]),      # r0_ohm_per_km
                parse(Float64, xline[i, :X0]),      # x0_ohm_per_km
                0.0,                                # c0_nf_per_km
                0.0,                                # g_us_per_km
                1.0,                                # max_i_ka
                1,                                  # parallel
                1.0,                                # df_star
                "cs",                               # line_type
                100.0,                              # max_loading_percent
                27.5,                               # endtemp_degree
                in_service_bool                     # in_service (布尔值)
            )
        end
    end
end
