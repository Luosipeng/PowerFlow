# 核心功能函数说明

## 潮流计算函数

### 1. 交流潮流计算
```julia
function ac_powerflow(bus::Matrix, branch::Matrix, gen::Matrix, opt::Dict)
```
执行交流潮流计算的主函数。

参数说明:
- `bus`: 母线数据矩阵
  - 每行代表一个母线
  - 列包含:编号、类型、电压幅值、相角等
- `branch`: 支路数据矩阵
  - 每行代表一条支路
  - 列包含:首末端母线、阻抗参数等
- `gen`: 发电机数据矩阵
- `opt`: 计算参数配置

主要步骤:
1. 形成节点导纳矩阵
2. 初始化状态变量
3. 牛顿-拉夫森迭代求解
4. 计算支路潮流
5. 收敛性检查

### 2. 直流潮流计算
```julia
function dc_powerflow(dcbus::Matrix, dcbranch::Matrix, battery::Matrix, opt::Dict)
```
执行直流系统潮流计算。

参数说明:
- `dcbus`: 直流母线数据
- `dcbranch`: 直流支路数据
- `battery`: 储能设备数据
- `opt`: 计算参数配置

特点:
- 线性方程组求解
- 考虑储能设备特性
- 支持多种控制模式

### 3. 混合潮流计算
```julia
function hybrid_powerflow(ac_system::SystemData, dc_system::SystemData, converter::Matrix, opt::Dict)
```
执行交直流混合系统潮流计算。

参数说明:
- `ac_system`: 交流系统数据
- `dc_system`: 直流系统数据
- `converter`: 换流器数据
- `opt`: 计算参数配置

核心功能:
- 统一迭代求解框架
- 换流器功率平衡
- 交直流系统接口处理

## 数据处理函数

### 1. 数据预处理
```julia
function preprocess_data!(mpc::Dict)
```
对输入数据进行预处理。

主要任务:
- 数据完整性检查
- 单位转换
- 基准值标幺化
- 参数有效性验证

### 2. 结果后处理
```julia
function postprocess_results!(results::Dict, base_mva::Float64)
```
处理计算结果。

功能:
- 标幺值还原
- 结果格式化
- 关键指标计算
- 越限检查

### 3. 数据验证
```julia
function validate_data(mpc::Dict)
```
验证输入数据的有效性。

检查项目:
- 数据格式正确性
- 参数取值范围
- 拓扑连接关系
- 控制模式设置

## 拓扑分析函数

### 1. 连通性分析
```julia
function check_connectivity(bus::Matrix, branch::Matrix)
```
分析网络连通性。

功能:
- 识别网络子系统
- 检测孤立节点
- 确定主网络范围
- 标记关键连接点

### 2. 并联支路处理
```julia
function process_parallel_branches!(branch::Matrix)
```
处理并联支路。

步骤:
- 识别并联支路
- 计算等效参数
- 更新支路数据
- 优化网络结构

### 3. 节点编号优化
```julia
function optimize_bus_numbers!(mpc::Dict)
```
优化节点编号方案。

目标:
- 减少带宽
- 优化矩阵结构
- 提高计算效率
- 便于数据管理

## 数值计算函数

### 1. 矩阵求解器
```julia
function solve_linear_system(Y::SparseMatrixCSC, b::Vector, opt::Dict)
```
求解线性方程组。

支持算法:
- 直接法(LU分解)
- 迭代法(GMRES)
- 预处理技术
- GPU加速

### 2. 雅可比矩阵计算
```julia
function calc_jacobian(V::Vector, Y::SparseMatrixCSC, pq::Vector, pv::Vector)
```
计算雅可比矩阵。

特点:
- 稀疏矩阵存储
- 高效更新策略
- 并行计算支持
- 内存优化

### 3. 收敛性控制
```julia
function check_convergence(dx::Vector, tol::Float64)
```
检查迭代收敛性。

功能:
- 误差计算
- 收敛判断
- 发散检测
- 迭代控制

## 辅助功能函数

### 1. 报告生成
```julia
function generate_report(results::Dict, filename::String)
```
生成计算报告。

内容:
- 计算概况
- 详细结果
- 越限信息
- 性能指标

### 2. 可视化函数
```julia
function plot_results(results::Dict, plot_type::String)
```
结果可视化。

支持类型:
- 电压分布
- 功率流向
- PV曲线
- 收敛特性

### 3. 数据导出
```julia
function export_results(results::Dict, format::String)
```
导出计算结果。

支持格式:
- Excel
- CSV
- JSON
- 自定义格式

## 错误处理函数

### 1. 异常检测
```julia
function check_errors(mpc::Dict)
```
检测输入数据错误。

检查项:
- 数据缺失
- 参数越限
- 拓扑错误
- 控制冲突

### 2. 警告处理
```julia
function handle_warnings(warnings::Vector)
```
处理计算过程中的警告。

类型:
- 收敛性问题
- 参数接近限值
- 数值精度问题
- 性能建议

### 3. 错误恢复
```julia
function recover_from_error(error_type::Symbol)
```
从错误状态恢复。

功能:
- 保存中间结果
- 恢复计算状态
- 调整计算参数
- 记录错误日志
```