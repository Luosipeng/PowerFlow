# 使用示例

本文档提供了PowerFlow.jl的详细使用示例,涵盖了常见的应用场景。

## 1. 基本交流潮流计算

### 1.1 IEEE 14节点系统示例
```julia
using PowerFlow

# 导入IEEE 14节点测试系统数据
mpc = loadcase("ieee14")

# 设置计算参数
opt = PowerFlow.options()
opt["PF"]["ALG"] = "NR"          # 使用牛顿-拉夫森法
opt["PF"]["TOL"] = 1e-6          # 收敛容差
opt["PF"]["MAX_IT"] = 30         # 最大迭代次数

# 执行潮流计算
results = runpf(mpc, opt)

# 显示计算结果
println("母线电压:")
display(results.bus[:, [1,2,3,4]])  # 显示母线编号、类型、电压幅值和相角

println("\n支路功率流:")
display(results.branch[:, [1,2,14,15]])  # 显示支路首末端功率
```

### 1.2 考虑无功功率限制
```julia
# 修改计算选项
opt["PF"]["ENFORCE_Q_LIMS"] = 1   # 启用无功功率限制
opt["PF"]["Q_LIMIT_METHOD"] = "ITER"  # 迭代法处理无功限制

# 重新计算
results_with_qlim = runpf(mpc, opt)

# 检查发电机无功出力
for i in 1:size(mpc["gen"],1)
    println("Generator $(Int(mpc["gen"][i,1])) Q output: $(results_with_qlim.gen[i,3])")
end
```

## 2. 交直流混合系统计算

### 2.1 基本混合系统示例
```julia
# 导入交直流混合系统数据
mpc_ac, mpc_dc = loadcase("hybrid_case")

# 配置混合潮流计算选项
opt = PowerFlow.options()
opt["PF"]["HYBRID_MODE"] = true
opt["PF"]["DC_TOL"] = 1e-4
opt["PF"]["VSC_LOSS"] = true     # 考虑换流器损耗

# 执行混合潮流计算
results = runhpf(mpc_ac, mpc_dc, opt)

# 分析结果
println("交流系统结果:")
display(results.ac.bus)
println("\n直流系统结果:")
display(results.dc.bus)
println("\n换流器运行状态:")
display(results.converter)
```

### 2.2 多端直流系统
```julia
# 导入多端直流系统数据
mtdc_case = loadcase("mtdc_test")

# 设置多端直流计算选项
opt["PF"]["MTDC_CONTROL"] = "VDM"  # 电压下垂控制
opt["PF"]["DROOP_CONST"] = 0.05    # 下垂系数

# 执行计算
mtdc_results = runhpf(mtdc_case, opt)

# 分析直流网络功率分布
plot_dc_power_flow(mtdc_results)
```

## 3. 网络拓扑分析

### 3.1 连通性分析
```julia
# 导入系统数据
mpc = loadcase("test_system")

# 分析网络连通性
islands = find_islands(mpc)
println("检测到 $(length(islands)) 个子网络")

# 显示各子网络信息
for (i, island) in enumerate(islands)
    println("子网络 $i:")
    println("节点数: $(length(island.buses))")
    println("发电机数: $(length(island.gens))")
end
```

### 3.2 关键支路识别
```julia
# 识别关键支路
critical_branches = find_critical_branches(mpc)

# 计算N-1可靠性
n1_results = check_n1_security(mpc)

# 显示薄弱环节
println("关键支路:")
for branch in critical_branches
    println("支路 $(Int(branch[1]))-$(Int(branch[2]))")
end
```

## 4. PV曲线分析

### 4.1 单节点PV曲线
```julia
# 设置PV曲线计算参数
pv_opt = PowerFlow.options()
pv_opt["PV"]["BUS"] = 5          # 研究节点
pv_opt["PV"]["STEP"] = 0.05      # 步长
pv_opt["PV"]["MAX_LOAD"] = 2.0   # 最大负荷倍数

# 计算PV曲线
pv_results = calc_pv_curve(mpc, pv_opt)

# 绘制曲线
plot_pv_curve(pv_results)
```

### 4.2 多节点电压稳定分析
```julia
# 设置多节点分析
buses = [5, 7, 9]  # 待分析节点
pv_opt["PV"]["MULTI_BUS"] = buses

# 执行分析
multi_pv_results = calc_multi_pv_curves(mpc, pv_opt)

# 绘制对比曲线
plot_multi_pv_curves(multi_pv_results)
```

## 5. 高级应用示例

### 5.1 GPU加速大规模计算
```julia
using CUDA

# 准备大规模系统数据
large_system = loadcase("case3120sp")

# 配置GPU计算选项
opt["PF"]["USE_GPU"] = true
opt["PF"]["GPU_BLOCK_SIZE"] = 256

# 执行GPU加速计算
gpu_results = runpf(large_system, opt)

# 对比CPU计算时间
opt["PF"]["USE_GPU"] = false
cpu_results = runpf(large_system, opt)

println("GPU计算时间: $(gpu_results.et) 秒")
println("CPU计算时间: $(cpu_results.et) 秒")
```

### 5.2 自定义求解器应用
```julia
# 定义自定义求解器
function my_custom_solver(Y, b, opt)
    # 实现自定义求解算法
    return solution
end

# 配置使用自定义求解器
opt["PF"]["SOLVER"] = my_custom_solver
opt["PF"]["CUSTOM_SOLVER_PARAMS"] = Dict(
    "param1" => value1,
    "param2" => value2
)

# 执行计算
results = runpf(mpc, opt)
```

### 5.3 结果可视化
```julia
# 绘制网络拓扑图
plot_network(mpc, results)

# 电压分布热力图
plot_voltage_heatmap(results)

# 功率流向图
plot_power_flow(results)

# 导出交互式HTML报告
generate_html_report(results, "power_flow_report.html")
```

## 6. 数据导入导出示例

### 6.1 从Excel导入数据
```julia
# 导入交流系统数据
mpc_ac = Excel_to_IEEE_acdc("ac_system.xlsx")

# 导入交直流混合系统数据
mpc_hybrid = Excel_to_IEEE_acdc("ac_system.xlsx", "dc_system.xlsx")
```

### 6.2 结果导出
```julia
# 导出到Excel
export_results(results, "results.xlsx")

# 导出到CSV格式
export_results(results, "results.csv")

# 导出到JSON格式
export_results(results, "results.json")
```

## 7. 错误处理示例

### 7.1 异常处理
```julia
try
    results = runpf(mpc, opt)
catch e
    if isa(e, ConvergenceError)
        println("潮流计算不收敛")
        # 尝试调整参数重新计算
        opt["PF"]["MAX_IT"] = 50
        results = runpf(mpc, opt)
    else
        rethrow(e)
    end
end
```

### 7.2 警告处理
```julia
# 设置警告级别
opt["VERBOSE"] = 2

# 启用警告日志
opt["WARNING_LOG"] = true

# 执行计算
results = runpf(mpc, opt)

# 检查警告信息
if !isempty(results.warnings)
    println("计算过程中的警告:")
    for warning in results.warnings
        println(warning)
    end
end
```
