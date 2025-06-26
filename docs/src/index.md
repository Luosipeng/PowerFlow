# PowerFlow.jl

PowerFlow.jl 是一个用于电力系统潮流计算的 Julia 包,支持交流、直流以及交直流混合系统的潮流分析。本包采用高效的数值计算方法,可处理大规模电力系统的稳态分析。

## 主要特性

### 1. 多种潮流计算支持
- 交流潮流计算(Newton-Raphson法)
- 直流潮流计算 
- 交直流混合潮流计算
- PV曲线分析
- 最优潮流计算(OPF)

### 2. 灵活的求解器选择
- 直接法
  - LU分解
  - Cholesky分解
- 迭代法
  - GMRES
  - BiCGSTAB
  - Conjugate Gradient
- GPU加速支持
  - CUDA.jl集成
  - 大规模矩阵运算优化

### 3. 完整的电力系统建模
- 发电机
  - 同步发电机
  - 光伏发电
  - 风力发电
  - 电网等效源
- 输电设备
  - 架空线路
  - 地下电缆
  - 变压器(两绕组、三绕组)
- 负荷建模
  - 恒功率(P)
  - 恒电流(I)
  - 恒阻抗(Z)
  - ZIP组合模型
- 直流设备
  - 逆变器/整流器
  - 储能电池
  - 直流线路
- 保护设备
  - 断路器(HVCB)
  - 隔离开关

### 4. 数据格式转换
- Excel格式数据导入/导出
- IEEE通用格式支持
- ETAP数据兼容
- PSS/E数据格式支持
- 自定义格式扩展接口

### 5. 网络拓扑处理
- 自动识别网络结构
- 孤岛检测与处理
- 并联支路合并
- 节点重编号优化
- 网络连通性分析

## 安装

使用Julia的包管理器安装:

```julia
using Pkg
Pkg.add("PowerFlow")
```

或者直接从GitHub安装开发版本:

```julia
using Pkg
Pkg.add(url="https://github.com/username/PowerFlow.jl")
```

## 快速开始

### 基本交流潮流计算

```julia
using PowerFlow

# 1. 导入系统数据
mpc, dict_bus, node_mapping, pv_curves = Excel_to_IEEE_acdc("system.xlsx")

# 2. 配置计算选项
opt = PowerFlow.options()
opt["PF"]["NR_ALG"] = "gmres"        # 选择求解算法
opt["PF"]["MAX_IT"] = 30             # 最大迭代次数
opt["PF"]["TOL"] = 1e-6              # 收敛容差
opt["PF"]["ENFORCE_Q_LIMS"] = 0      # 无功功率限制

# 3. 执行潮流计算
results = runpf(mpc, opt)

# 4. 查看结果
println("计算结果:")
println("收敛状态: ", results.success)
println("迭代次数: ", results.iterations)
println("计算时间: ", results.et, " 秒")
```

### 交直流混合潮流计算

```julia
# 1. 导入AC/DC混合系统数据
mpc, dict_bus, node_mapping, pv_curves = Excel_to_IEEE_acdc("ac_system.xlsx", "dc_system.xlsx")

# 2. 配置混合潮流计算选项
opt = PowerFlow.options()
opt["PF"]["HYBRID_MODE"] = true
opt["PF"]["DC_TOL"] = 1e-4

# 3. 执行混合潮流计算
results = runhpf(mpc, opt)
```

## 性能特点

- 高效的稀疏矩阵处理
- 多线程并行计算支持
- GPU加速大规模计算
- 内存优化的数据结构
- 快速收敛的迭代算法

## 文档结构

- [API参考](api.md): 详细的函数接口说明
  - 核心函数文档
  - 数据结构定义
  - 参数配置说明
  
- [使用示例](examples.md): 常见应用场景示例
  - 基础潮流计算
  - 交直流混合系统
  - PV曲线分析
  - 网络拓扑处理
  
- [函数说明](functions.md): 核心功能函数文档
  - 潮流计算函数
  - 数据处理函数
  - 拓扑分析函数

## 贡献指南

欢迎通过以下方式参与项目:
1. 提交Issue报告bug或提出新功能建议
2. 提交Pull Request贡献代码
3. 完善文档和示例
4. 分享使用经验和应用案例

## 许可证

本项目采用MIT许可证。详见[LICENSE](LICENSE)文件。

## 引用

如果您在研究中使用了PowerFlow.jl,请引用:

```bibtex
@software{PowerFlow2025,
  author = {Author Name},
  title = {PowerFlow.jl: A Power Flow Analysis Tool in Julia},
  year = {2025},
  publisher = {GitHub},
  url = {https://github.com/username/PowerFlow.jl}
}
```
```
