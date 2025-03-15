using Test
using Printf

"""
模拟电力系统元件的基本结构体
"""
mutable struct MockElement
    name::Union{String, Nothing}
    element_type::String
    valid::Bool
    validation_error::Union{String, Nothing}
end

"""
对电力系统中的所有元件进行自检，验证参数是否符合要求
- elements::Dict: 包含所有电力系统元件的字典，键为元件ID，值为元件对象
- 返回：检验结果的报表
"""
function validate_power_system_elements(elements::Dict)
    # 初始化结果统计
    results = Dict()
    
    # 遍历所有元件并进行验证
    for (id, element) in elements
        element_type = element.element_type
        
        # 确保结果字典中有相应的元件类型键
        if !haskey(results, element_type)
            results[element_type] = Dict(
                "total" => 0,
                "passed" => 0,
                "failed" => 0,
                "failures" => Dict()
            )
        end
        
        # 增加该类型元件的总数
        results[element_type]["total"] += 1
        
        # 验证元件
        if element.valid
            # 验证通过，增加通过计数
            results[element_type]["passed"] += 1
        else
            # 验证失败，增加失败计数并记录失败原因
            results[element_type]["failed"] += 1
            
            # 获取元件名称（用于报告）
            element_name = isnothing(element.name) ? "ID_$(id)" : element.name
            
            # 记录失败原因
            results[element_type]["failures"][element_name] = element.validation_error
        end
    end
    
    # 返回结果字典和生成的报表
    return results, generate_validation_report(results)
end

"""
生成元件验证报表
- results::Dict: 包含验证结果的字典
- 返回：格式化的报表字符串
"""
function generate_validation_report(results::Dict)
    # 初始化报表
    report = "电力系统元件自检报告\n"
    report *= "=" ^ 80 * "\n\n"
    
    # 添加总体统计信息
    total_elements = 0
    total_passed = 0
    total_failed = 0
    
    for type in keys(results)
        if haskey(results[type], "total")
            total_elements += results[type]["total"]
            total_passed += results[type]["passed"]
            total_failed += results[type]["failed"]
        end
    end
    
    report *= "总体统计:\n"
    report *= "-" ^ 80 * "\n"
    report *= "元件总数: $(total_elements)\n"
    report *= "通过元件数: $(total_passed)\n"
    report *= "故障元件数: $(total_failed)\n"
    
    if total_elements > 0
        report *= "通过率: $(round(total_passed / total_elements * 100, digits=2))%\n\n"
    else
        report *= "通过率: 0.00%\n\n"
    end
    
    # 添加各类元件的统计信息
    report *= "各类元件统计:\n"
    report *= "-" ^ 80 * "\n"
    report *= @sprintf("%-30s %-10s %-10s %-10s %-10s\n", "元件类型", "总数", "通过数", "故障数", "通过率(%)")
    report *= "-" ^ 80 * "\n"
    
    # 只显示系统中存在的元件类型
    for element_type in sort(collect(keys(results)))
        stats = results[element_type]
        if haskey(stats, "total") && stats["total"] > 0
            pass_rate = stats["total"] > 0 ? round(stats["passed"] / stats["total"] * 100, digits=2) : 0.0
            report *= @sprintf("%-30s %-10d %-10d %-10d %-10.2f\n", 
                element_type, stats["total"], stats["passed"], stats["failed"], pass_rate)
        end
    end
    
    report *= "\n"
    
    # 添加故障元件详情
    has_failures = false
    
    for element_type in sort(collect(keys(results)))
        if haskey(results[element_type], "failures")
            failures = results[element_type]["failures"]
            if !isempty(failures)
                if !has_failures
                    report *= "故障元件详情:\n"
                    report *= "-" ^ 80 * "\n"
                    has_failures = true
                end
                
                report *= "$(element_type):\n"
                for (element_name, reason) in failures
                    report *= "  - $(element_name): $(reason)\n"
                end
                report *= "\n"
            end
        end
    end
    
    if !has_failures
        report *= "所有元件验证通过！\n"
    end
    
    return report
end

"""
使用@test进行电力系统元件自检程序的测试
"""
function test_power_system_validation()
    @testset "电力系统元件自检程序测试" begin
        # 测试集1: 所有元件都有效
        @testset "所有元件有效" begin
            elements = Dict()
            # 创建有效的模拟元件
            elements[1] = MockElement("母线1", "Bus", true, nothing)
            elements[2] = MockElement("线路1", "Line", true, nothing)
            elements[3] = MockElement("变压器1", "Transformer", true, nothing)
            
            results, report = validate_power_system_elements(elements)
            
            @test haskey(results, "Bus")
            @test results["Bus"]["total"] == 1
            @test results["Bus"]["passed"] == 1
            @test results["Bus"]["failed"] == 0
            
            @test haskey(results, "Line")
            @test results["Line"]["total"] == 1
            @test results["Line"]["passed"] == 1
            @test results["Line"]["failed"] == 0
            
            @test haskey(results, "Transformer")
            @test results["Transformer"]["total"] == 1
            @test results["Transformer"]["passed"] == 1
            @test results["Transformer"]["failed"] == 0
            
            # 测试总体统计
            total_elements = 0
            total_passed = 0
            total_failed = 0
            
            for type in keys(results)
                if haskey(results[type], "total")
                    total_elements += results[type]["total"]
                    total_passed += results[type]["passed"]
                    total_failed += results[type]["failed"]
                end
            end
            
            @test total_elements == 3
            @test total_passed == 3
            @test total_failed == 0
            
            # 检查报表中是否包含"所有元件验证通过"
            @test occursin("所有元件验证通过", report)
        end
        
        # 测试集2: 包含无效元件
        @testset "包含无效元件" begin
            elements = Dict()
            # 创建有效和无效的模拟元件
            elements[1] = MockElement("母线1", "Bus", true, nothing)
            elements[2] = MockElement("错误母线", "Bus", false, "电压值不在允许范围内")
            elements[3] = MockElement("线路1", "Line", true, nothing)
            elements[4] = MockElement("错误线路", "Line", false, "长度为负值")
            
            results, report = validate_power_system_elements(elements)
            
            @test haskey(results, "Bus")
            @test results["Bus"]["total"] == 2
            @test results["Bus"]["passed"] == 1
            @test results["Bus"]["failed"] == 1
            
            @test haskey(results, "Line")
            @test results["Line"]["total"] == 2
            @test results["Line"]["passed"] == 1
            @test results["Line"]["failed"] == 1
            
            # 测试总体统计
            total_elements = 0
            total_passed = 0
            total_failed = 0
            
            for type in keys(results)
                if haskey(results[type], "total")
                    total_elements += results[type]["total"]
                    total_passed += results[type]["passed"]
                    total_failed += results[type]["failed"]
                end
            end
            
            @test total_elements == 4
            @test total_passed == 2
            @test total_failed == 2
            
            # 检查报表中是否包含故障元件详情
            @test occursin("故障元件详情", report)
            @test occursin("错误母线", report)
            @test occursin("错误线路", report)
            @test occursin("电压值不在允许范围内", report)
            @test occursin("长度为负值", report)
        end
        
        # 测试集3: 空元件字典
        @testset "空元件字典" begin
            elements = Dict()
            results, report = validate_power_system_elements(elements)
            
            # 测试总体统计
            total_elements = 0
            total_passed = 0
            total_failed = 0
            
            for type in keys(results)
                if haskey(results[type], "total")
                    total_elements += results[type]["total"]
                    total_passed += results[type]["passed"]
                    total_failed += results[type]["failed"]
                end
            end
            
            @test total_elements == 0
            @test total_passed == 0
            @test total_failed == 0
            
            # 检查报表中的通过率
            @test occursin("通过率: 0.00%", report)
        end
        
        # 测试集4: 不同类型元件的混合
        @testset "混合元件测试" begin
            elements = Dict()
            # 创建不同类型的模拟元件
            elements[1] = MockElement("母线1", "Bus", true, nothing)
            elements[2] = MockElement("线路1", "Line", true, nothing)
            elements[3] = MockElement("发电机1", "Generator", false, "功率因数超出范围")
            elements[4] = MockElement("变压器1", "Transformer", true, nothing)
            elements[5] = MockElement("开关1", "Switch", false, "电流超出额定值")
            
            results, report = validate_power_system_elements(elements)
            
            # 测试各类型元件统计
            @test haskey(results, "Bus")
            @test results["Bus"]["total"] == 1
            @test results["Bus"]["passed"] == 1
            
            @test haskey(results, "Line")
            @test results["Line"]["total"] == 1
            @test results["Line"]["passed"] == 1
            
            @test haskey(results, "Generator")
            @test results["Generator"]["total"] == 1
            @test results["Generator"]["failed"] == 1
            
            @test haskey(results, "Transformer")
            @test results["Transformer"]["total"] == 1
            @test results["Transformer"]["passed"] == 1
            
            @test haskey(results, "Switch")
            @test results["Switch"]["total"] == 1
            @test results["Switch"]["failed"] == 1
            
            # 测试总体统计
            total_elements = 0
            total_passed = 0
            total_failed = 0
            
            for type in keys(results)
                if haskey(results[type], "total")
                    total_elements += results[type]["total"]
                    total_passed += results[type]["passed"]
                    total_failed += results[type]["failed"]
                end
            end
            
            @test total_elements == 5
            @test total_passed == 3
            @test total_failed == 2
            
            # 检查报表中是否包含故障元件详情
            @test occursin("故障元件详情", report)
            @test occursin("功率因数超出范围", report)
            @test occursin("电流超出额定值", report)
        end
    end
end

# 运行测试
test_power_system_validation()
