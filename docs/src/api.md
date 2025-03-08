# API 参考文档

## 核心函数

### runpf
```julia
function runpf(mpc::Dict, opt::Dict)
```
执行交流潮流计算。

参数:
- `mpc`: 包含系统数据的字典
- `opt`: 计算选项字典

返回:
- `results`: 包含计算结果的字典

### runhpf
```julia
function runhpf(mpc::Dict, opt::Dict)
```
执行交直流混合潮流计算。

参数:
- `mpc`: 包含系统数据的字典
- `opt`: 计算选项字典

返回:
- `results`: 包含计算结果的字典

### rundcpf
```julia
function rundcpf(mpc::Dict, opt::Dict)
```
执行直流潮流计算。

参数:
- `mpc`: 包含系统数据的字典
- `opt`: 计算选项字典

返回:
- `results`: 包含计算结果的字典

## 数据结构

### PVCurves
```julia
struct PVCurves
    generation_curve1::Union{Function, Nothing}
    generation_curve2::Union{Function, Nothing}
    absorption_curve1::Union{Function, Nothing}
    absorption_curve2::Union{Function, Nothing}
end
```
用于存储逆变器的PV特性曲线。

### SystemData
```julia
struct SystemData
    bus::Matrix{Float64}
    branch::Matrix{Float64}
    gen::Matrix{Float64}
    dcbus::Matrix{Float64}
    dcbranch::Matrix{Float64}
    converter::Matrix{Float64}
end
```
存储系统基础数据的结构体。

### Results
```julia
struct Results
    bus::Matrix{Float64}
    branch::Matrix{Float64}
    gen::Matrix{Float64}
    dcResults::Union{DCResults, Nothing}
    success::Bool
    et::Float64
end
```
存储潮流计算结果的结构体。

## 数据转换函数

### Excel_to_IEEE_acdc
```julia
function Excel_to_IEEE_acdc(file_path, DCfile_path=nothing)
```
将Excel格式的电力系统数据转换为IEEE格式。

参数:
- `file_path`: AC系统Excel文件路径
- `DCfile_path`: DC系统Excel文件路径(可选)

返回:
- `mpc`: 包含系统数据的字典
- `dict_bus`: 母线映射字典
- `node_mapping`: 节点编号映射
- `pv_curves`: PV曲线数据结构

### IEEE_to_Excel
```julia
function IEEE_to_Excel(mpc::Dict, output_path::String)
```
将IEEE格式数据转换回Excel格式。

参数:
- `mpc`: 包含系统数据的字典
- `output_path`: 输出Excel文件路径

### ETAP_to_IEEE
```julia
function ETAP_to_IEEE(etap_file::String)
```
将ETAP格式数据转换为IEEE格式。

参数:
- `etap_file`: ETAP文件路径

返回:
- `mpc`: 包含系统数据的字典

## 配置选项

### options
```julia
function options()
```
返回默认配置选项字典。

主要选项包括:
- `PF.NR_ALG`: 牛顿-拉夫森法求解算法选择
- `PF.MAX_IT`: 最大迭代次数
- `PF.TOL`: 收敛容差
- `PF.ENFORCE_Q_LIMS`: 是否强制Q限制
- `PF.SOLVER`: 线性方程组求解器选择

## 索引常量

### 交流系统索引
```julia
# 母线索引
EquipmentID, Voltage, Initial_Voltage, In_Service, Bus_Type = bus_idx()

# 发电机索引
Gen_connected_element, Gen_inservice, Gen_controlmode, Gen_power_rating,
Gen_apparent_power_rating, Gen_voltage = gen_idx()

# 负荷索引
ConectedID, load_inservice, load_kva, load_pf = load_idx()

# 线路索引
Branch_ID, Branch_inservice, Branch_Felement, Branch_Telement,
Branch_R, Branch_X, Branch_B = branch_idx()
```

### 直流系统索引
```julia
# 直流母线索引
DCBUS_ID, DCBUS_V, DCBUS_INSERVICE = dcbus_idx()

# 电池索引
BATTERY_ID, BATTERY_INSERVICE, BATTERY_CONNECTED_BUS,
BATTERY_CELLS, BATTERY_PACKS, BATTERY_STRINGS = battery_idx()

# 逆变器索引
inverter_ID, inverter_inservice, inverter_Felement, inverter_Telement,
inverter_eff, inverter_Pac, inverter_Qac = inverter_idx()

# 直流线路索引
DCBRANCH_ID, DCBRANCH_INSERVICE, DCBRANCH_FELEMENT,
DCBRANCH_TELEMENT, DCBRANCH_R = dcbranch_idx()
```

## 辅助函数

### process_topology!
```julia
function process_topology!(branch::Matrix, bus::Matrix, HVCB_data::Matrix)
```
处理系统拓扑结构,包括断路器状态。

参数:
- `branch`: 支路数据矩阵
- `bus`: 母线数据矩阵
- `HVCB_data`: 断路器数据矩阵

返回:
- `branch`: 更新后的支路数据
- `bus`: 更新后的母线数据
- `HVCB_data`: 更新后的断路器数据

### process_islands
```julia
function process_islands(bus::Matrix, branch::Matrix, HVCB_data::Matrix; threshold::Int=10)
```
检测和处理电气孤岛。

参数:
- `bus`: 母线数据矩阵
- `branch`: 支路数据矩阵
- `HVCB_data`: 断路器数据矩阵
- `threshold`: 孤岛节点数阈值(默认10)

返回:
- `bus_new`: 处理后的母线数据
- `branch_new`: 处理后的支路数据

### merge_parallel_branches!
```julia
function merge_parallel_branches!(branch::Matrix, FBUS::Int, TBUS::Int, R::Float64, X::Float64, B::Float64)
```
合并并联支路。

参数:
- `branch`: 支路数据矩阵
- `FBUS`: 起始母线编号
- `TBUS`: 终止母线编号
- `R`: 电阻值
- `X`: 电抗值
- `B`: 导纳值

返回:
- `branch`: 更新后的支路数据
```

