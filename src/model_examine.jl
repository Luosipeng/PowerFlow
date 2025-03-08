"""
This module contains the classes for the electrical components of the power system, including the following 25 class:
1) Network
2) Bus
3) DC Bus
4) Line
5) Line DC
6) Switch
7) Load
8) Motor
9) Asymmetric Load
10) Static Generator
11) External Grid
12) Transformer
13) Three Winding Transformer
14) Generator
15) Shunt
16) Impedance
17) Ward
18) Extended Ward
19) DC Line
20) Measurement
21) Storage
22) Static Var Compensator
23) Thyristor Controlled Series Compensator (TCSC)
24) Static Synchronous Compensator (SSC)
25) Voltage Source Converter (VSC)
"""

"""
bus参数
- name::Union{String, Nothing}: bus的名称（可选）
- vn_kv::Float64: bus的额定电压 [kV]
- bus_type::String: bus的类型，必须是 'n', 'b' 或 'm'
- max_vm_pu::Float64: 最大电压标幺值
- min_vm_pu::Float64: 最小电压标幺值
- in_service::Bool: bus是否在运行状态
"""
struct Bus
    name::Any
    vn_kv::Float64
    bus_type::String
    max_vm_pu::Float64
    min_vm_pu::Float64
    in_service::Bool
end

function validate_bus_parameters(vn_kv::Float64, bus_type::String, max_vm_pu::Float64, 
    min_vm_pu::Float64, in_service::Bool, name::Union{String, Nothing}=nothing)
    # 验证额定电压
    if vn_kv <= 0
        throw(ArgumentError("额定电压 vn_kv 必须大于0"))
    end

    # 验证bus类型
    valid_types = ["n", "b", "m"]
    if !(bus_type in valid_types)
        throw(ArgumentError("bus类型必须是 $(valid_types) 之一"))
    end

    # 验证最大电压标幺值
    if max_vm_pu <= 0
        throw(ArgumentError("最大电压标幺值 max_vm_pu 必须大于0"))
    end

    # 验证最小电压标幺值
    if min_vm_pu <= 0
        throw(ArgumentError("最小电压标幺值 min_vm_pu 必须大于0"))
    end

    # 验证最大最小电压的关系
    if min_vm_pu > max_vm_pu
        throw(ArgumentError("最小电压标幺值不能大于最大电压标幺值"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("运行状态 in_service 必须是布尔值"))
    end

    return true
end

"""
直流bus的数据结构
- name::Union{String, Nothing}: bus的名称（可选）
- vn_kv::Float64: 额定电压 [kV]
- bus_type::String: bus类型 ('n', 'b', 'm')
- in_service::Bool: 运行状态
"""
struct DcBus
    name::Union{String, Nothing}
    vn_kv::Float64
    bus_type::String
    in_service::Bool
end

function validate_dc_bus_parameters(vn_kv::Float64, bus_type::String, 
    in_service::Bool, name::Union{String, Nothing}=nothing)
    # 验证额定电压
    if vn_kv <= 0
        throw(ArgumentError("额定电压 vn_kv 必须大于0"))
    end

    # 验证bus类型
    valid_types = ["n", "b", "m"]
    if !(bus_type in valid_types)
        throw(ArgumentError("bus类型必须是 $(valid_types) 之一"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("运行状态 in_service 必须是布尔值"))
    end

    return true
end

"""
输电线路的数据结构
- name::Union{String, Nothing}: 线路名称（可选）
- length_km::Float64: 线路长度 [km]
- r_ohm_per_km::Float64: 线路电阻 [Ohm/km]
- x_ohm_per_km::Float64: 线路电抗 [Ohm/km]
- c_nf_per_km::Float64: 线路对地电容 [nF/km]
- r0_ohm_per_km::Float64: 零序电阻 [Ohm/km]
- x0_ohm_per_km::Float64: 零序电抗 [Ohm/km]
- c0_nf_per_km::Float64: 零序电容 [nF/km]
- g_us_per_km::Float64: 介质电导 [μS/km]
- max_i_ka::Float64: 最大热电流 [kA]
- parallel::Int: 并联线路数量
- df_star::Float64: 最大电流降额系数
- line_type::String: 线路类型 ('ol' 或 'cs')
- max_loading_percent::Float64: 最大负载百分比
- endtemp_degree::Float64: 短路末端温度
- in_service::Bool: 运行状态
- lambda_pu::Float64: 故障率
- tau_sw::Float64: 开关时间（小时）
- taw_rp::Float64: 修复时间（小时）
"""
struct Line
    name::Any
    length_km::Float64
    r_ohm_per_km::Float64
    x_ohm_per_km::Float64
    c_nf_per_km::Float64
    r0_ohm_per_km::Float64
    x0_ohm_per_km::Float64
    c0_nf_per_km::Float64
    g_us_per_km::Float64
    max_i_ka::Float64
    parallel::Int
    df_star::Float64
    line_type::String
    max_loading_percent::Float64
    endtemp_degree::Float64
    in_service::Bool
    lambda_pu::Float64
    tau_sw::Float64
    taw_rp::Float64
end

function validate_line_parameters(
    length_km::Float64,
    r_ohm_per_km::Float64,
    x_ohm_per_km::Float64,
    c_nf_per_km::Float64,
    r0_ohm_per_km::Float64,
    x0_ohm_per_km::Float64,
    c0_nf_per_km::Float64,
    g_us_per_km::Float64,
    max_i_ka::Float64,
    parallel::Int,
    df_star::Float64,
    line_type::String,
    max_loading_percent::Float64,
    endtemp_degree::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing,
    lambda_pu::Float64=0.0,
    tau_sw::Float64=0.0,
    taw_rp::Float64=0.0
)
    # 验证线路长度
    if length_km <= 0
        throw(ArgumentError("length_km必须大于0"))
    end

    # 验证各种电气参数非负
    if r_ohm_per_km < 0
        throw(ArgumentError("r_ohm_per_km必须大于等于0"))
    end
    if x_ohm_per_km < 0
        throw(ArgumentError("x_ohm_per_km必须大于等于0"))
    end
    if c_nf_per_km < 0
        throw(ArgumentError("c_nf_per_km必须大于等于0"))
    end
    if r0_ohm_per_km < 0
        throw(ArgumentError("r0_ohm_per_km必须大于等于0"))
    end
    if x0_ohm_per_km < 0
        throw(ArgumentError("x0_ohm_per_km必须大于等于0"))
    end
    if c0_nf_per_km < 0
        throw(ArgumentError("c0_nf_per_km必须大于等于0"))
    end
    if g_us_per_km < 0
        throw(ArgumentError("g_us_per_km必须大于等于0"))
    end

    # 验证最大电流
    if max_i_ka < 0
        throw(ArgumentError("max_i_ka必须大于0"))
    end

    # 验证并联数量
    if parallel < 1
        throw(ArgumentError("parallel必须大于等于1"))
    end

    # 验证线路类型
    if !(line_type in ["ol", "cs"])
        throw(ArgumentError("line_type必须是 'ol' 或 'cs'"))
    end

    # 验证最大负载百分比
    if max_loading_percent <= 0
        throw(ArgumentError("max_loading_percent必须大于0"))
    end

    # 验证末端温度
    if endtemp_degree <= 0
        throw(ArgumentError("endtemp_degree必须大于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
直流输电线路的数据结构
- name::Union{String, Nothing}: 线路名称（可选）
- length_km::Float64: 线路长度 [km]
- r_ohm_per_km::Float64: 线路电阻 [Ohm/km]
- g_us_per_km::Float64: 介质电导 [μS/km]
- max_i_ka::Float64: 最大热电流 [kA]
- parallel::Int: 并联线路数量
- df_star::Float64: 最大电流降额系数
- max_loading_percent::Float64: 最大负载百分比
- in_service::Bool: 运行状态
"""
struct LineDc
    name::Union{String, Nothing}
    length_km::Float64
    r_ohm_per_km::Float64
    g_us_per_km::Float64
    max_i_ka::Float64
    parallel::Int
    df_star::Float64
    max_loading_percent::Float64
    in_service::Bool
end

function validate_dc_line_parameters(
    length_km::Float64,
    r_ohm_per_km::Float64,
    g_us_per_km::Float64,
    max_i_ka::Float64,
    parallel::Int,
    df_star::Float64,
    max_loading_percent::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证线路长度
    if length_km <= 0
        throw(ArgumentError("length_km必须大于0"))
    end

    # 验证线路电阻
    if r_ohm_per_km < 0
        throw(ArgumentError("r_ohm_per_km必须大于等于0"))
    end

    # 验证介质电导
    if g_us_per_km < 0
        throw(ArgumentError("g_us_per_km必须大于等于0"))
    end

    # 验证最大电流
    if max_i_ka <= 0
        throw(ArgumentError("max_i_ka必须大于0"))
    end

    # 验证并联数量
    if parallel < 1
        throw(ArgumentError("parallel必须大于等于1"))
    end

    # 验证最大负载百分比
    if max_loading_percent <= 0
        throw(ArgumentError("max_loading_percent必须大于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
开关设备的数据结构
- name::Union{String, Nothing}: 开关名称（可选）
- et::String: 连接的元件类型 ('b','l','t','t3')
- switch_type::String: 开关类型 ('CB','LS','LBS','DS')
- closed::Bool: 开关状态
- in_ka::Float64: 正常运行条件下的最大允许电流 [kA]
"""
struct Switch
    name::Union{String, Nothing}
    et::String
    switch_type::String
    closed::Bool
    in_ka::Float64
end

function validate_switch_parameters(
    et::String,
    switch_type::String,
    closed::Bool,
    in_ka::Float64,
    name::Union{String, Nothing}=nothing
)
    # 验证连接元件类型
    valid_et = ["b", "l", "t", "t3"]
    if !(et in valid_et)
        throw(ArgumentError("et必须是以下之一: $(valid_et)"))
    end

    # 验证开关类型
    valid_switch_types = ["CB", "LS", "LBS", "DS"]
    if !(switch_type in valid_switch_types)
        throw(ArgumentError("switch_type必须是以下之一: $(valid_switch_types)"))
    end

    # 验证开关状态
    if !isa(closed, Bool)
        throw(ArgumentError("closed必须是布尔值"))
    end

    # 验证额定电流
    if in_ka <= 0
        throw(ArgumentError("in_ka必须大于0"))
    end

    return true
end

"""
负载的数据结构
- name::Union{String, Nothing}: 负载名称（可选）
- p_mw::Float64: 负载有功功率 [MW]
- const_z_percent::Float64: 额定电压下恒阻抗负载的百分比 [%]
- const_i_percent::Float64: 额定电压下恒电流负载的百分比 [%]
- sn_mva::Float64: 负载的额定功率 [kVA]
- scaling::Float64: 有功和无功功率的缩放因子
- in_service::Bool: 运行状态
- load_type::String: 三相负载的连接方式（'wye'或'delta'）
"""
struct Load
    name::Union{String, Nothing}
    p_mw::Float64
    const_z_percent::Float64
    const_i_percent::Float64
    sn_mva::Float64
    scaling::Float64
    in_service::Bool
    load_type::String
end

function validate_load_parameters(
    p_mw::Float64,
    const_z_percent::Float64,
    const_i_percent::Float64,
    sn_mva::Float64,
    scaling::Float64,
    in_service::Bool,
    load_type::String,
    name::Union{String, Nothing}=nothing
)
    # 验证有功功率
    if p_mw < 0
        throw(ArgumentError("p_mw必须大于等于0"))
    end

    # 验证额定功率
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end

    # 验证缩放因子
    if scaling < 0
        throw(ArgumentError("scaling必须大于等于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    # 验证负载类型
    valid_load_types = ["wye", "delta"]
    if !(load_type in valid_load_types)
        throw(ArgumentError("load_type必须是以下之一: $(valid_load_types)"))
    end

    return true
end


"""
电动机的数据结构
- name::Union{String, Nothing}: 电动机名称（可选）
- pn_mech_mw::Float64: 电动机的机械额定功率 [MW]
- cos_phi::Float64: 当前运行点的功率因数
- cos_phi_n::Float64: 用于短路计算的额定功率下的功率因数
- efficiency_percent::Float64: 当前运行点的效率 [%]
- efficiency_n_percent::Float64: 用于短路计算的额定功率下的效率 [%]
- loading_percent::Float64: 负载百分比 [%]
- scaling::Float64: 有功和无功功率的缩放因子
- lrc_pu::Float64: 锁转子电流与额定电机电流的比值 [pu]
- rx::Float64: 用于短路计算的电动机R/X比
- vn_kv::Float64: 用于短路计算的电动机额定电压
- in_service::Bool: 运行状态
"""
struct Motor
    name::Union{String, Nothing}
    pn_mech_mw::Float64
    cos_phi::Float64
    cos_phi_n::Float64
    efficiency_percent::Float64
    efficiency_n_percent::Float64
    loading_percent::Float64
    scaling::Float64
    lrc_pu::Float64
    rx::Float64
    vn_kv::Float64
    in_service::Bool
end

function validate_motor_parameters(
    pn_mech_mw::Float64,
    cos_phi::Float64,
    cos_phi_n::Float64,
    efficiency_percent::Float64,
    efficiency_n_percent::Float64,
    loading_percent::Float64,
    scaling::Float64,
    lrc_pu::Float64,
    rx::Float64,
    vn_kv::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证机械额定功率
    if pn_mech_mw < 0
        throw(ArgumentError("pn_mech_mw必须大于等于0"))
    end

    # 验证缩放因子
    if scaling < 0
        throw(ArgumentError("scaling必须大于等于0"))
    end

    # 验证锁转子电流比值
    if lrc_pu < 0
        throw(ArgumentError("lrc_pu必须大于等于0"))
    end

    # 验证R/X比
    if rx < 0
        throw(ArgumentError("rx必须大于等于0"))
    end

    # 验证额定电压
    if vn_kv < 0
        throw(ArgumentError("vn_kv必须大于等于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
静态发电机的数据结构
- name::Union{String, Nothing}: 静态发电机名称（可选）
- sg_type::String: 发电机类型 ('pv','wp','chp')
- p_mw::Float64: 静态发电机的有功功率 [MW]
- sn_mva::Float64: 静态发电机的额定功率 [MVA]
- scaling::Float64: 有功和无功功率的缩放因子
- k_star::Float64: 短路电流与额定电流的比值
- rx::Float64: 短路阻抗的R/X比（仅当发电机作为异步电动机处理时相关）
- in_service::Bool: 运行状态
"""
struct StaticGenerator
    name::Union{String, Nothing}
    sg_type::String
    p_mw::Float64
    sn_mva::Float64
    scaling::Float64
    k_star::Float64
    rx::Float64
    in_service::Bool
end

function validate_static_generator_parameters(
    sg_type::String,
    p_mw::Float64,
    sn_mva::Float64,
    scaling::Float64,
    k_star::Float64,
    rx::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证发电机类型
    valid_types = ["pv", "wp", "chp"]
    if !(sg_type in valid_types)
        throw(ArgumentError("sg_type必须是以下之一: $(valid_types)"))
    end

    # 验证额定功率
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end

    # 验证缩放因子
    if scaling < 0
        throw(ArgumentError("scaling必须大于等于0"))
    end

    # 验证短路电流比
    if k_star < 0
        throw(ArgumentError("k_star必须大于等于0"))
    end

    # 验证R/X比
    if rx < 0
        throw(ArgumentError("rx必须大于等于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
不对称静态发电机的数据结构
- name::Union{String, Nothing}: 静态发电机名称（可选）
- asg_type::String: 发电机类型 ('pv','wp','chp')
- p_a_mw::Float64: A相有功功率 [MW]
- p_b_mw::Float64: B相有功功率 [MW]
- p_c_mw::Float64: C相有功功率 [MW]
- sn_mva::Float64: 静态发电机的额定功率 [MVA]
- scaling::Float64: 有功和无功功率的缩放因子
- in_service::Bool: 运行状态
"""
struct AsymmetricStaticGenerator
    name::Union{String, Nothing}
    asg_type::String
    p_a_mw::Float64
    p_b_mw::Float64
    p_c_mw::Float64
    sn_mva::Float64
    scaling::Float64
    in_service::Bool
end

function validate_asymmetric_static_generator_parameters(
    asg_type::String,
    p_a_mw::Float64,
    p_b_mw::Float64,
    p_c_mw::Float64,
    sn_mva::Float64,
    scaling::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证发电机类型
    valid_types = ["pv", "wp", "chp"]
    if !(asg_type in valid_types)
        throw(ArgumentError("asg_type必须是以下之一: $(valid_types)"))
    end

    # 验证额定功率
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end

    # 验证缩放因子
    if scaling <= 0
        throw(ArgumentError("scaling必须大于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
外部电网的数据结构
- name::Union{String, Nothing}: 外部电网名称（可选）
- vm_pu::Float64: 电压设定值 [标幺值]
- s_sc_max_mva::Float64: 最大短路功率 [MVA]
- s_sc_min_mva::Float64: 最小短路功率 [MVA]
- rx_max::Float64: 短路阻抗最大R/X比
- rx_min::Float64: 短路阻抗最小R/X比
- r0x0_max::Float64: 计算外部电网零序内阻抗的最大R/X比
- x0x::Float64: 计算外部电网零序内阻抗的最大X0/X比
- in_service::Bool: 运行状态
"""
struct ExternalGrid
    name::Union{String, Nothing}
    vm_pu::Float64
    s_sc_max_mva::Float64
    s_sc_min_mva::Float64
    rx_max::Float64
    rx_min::Float64
    r0x0_max::Float64
    x0x::Float64
    in_service::Bool
end

function validate_external_grid_parameters(
    vm_pu::Float64,
    s_sc_max_mva::Float64,
    s_sc_min_mva::Float64,
    rx_max::Float64,
    rx_min::Float64,
    r0x0_max::Float64,
    x0x::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证电压设定值
    if vm_pu <= 0
        throw(ArgumentError("vm_pu必须大于0"))
    end

    # 验证最大短路功率
    if s_sc_max_mva <= 0
        throw(ArgumentError("s_sc_max_mva必须大于0"))
    end

    # 验证最小短路功率
    if s_sc_min_mva <= 0
        throw(ArgumentError("s_sc_min_mva必须大于0"))
    end

    # 验证运行状态
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
变压器的数据结构
- name::Union{String, Nothing}: 变压器名称（可选）
- sn_mva::Float64: 变压器额定视在功率 [MVA]
- vn_hv_kv::Float64: 高压侧额定电压 [kV]
- vn_lv_kv::Float64: 低压侧额定电压 [kV]
- vk_percent::Float64: 短路电压 [%]
- vkr_percent::Float64: 短路电压的实部 [%]
- pfe_kw::Float64: 铁损 [kW]
- i0_percent::Float64: 空载损耗 [%]
- vk0_percent::Float64: 零序相对短路电压
- vkr0_percent::Float64: 零序相对短路电压的实部
- mag0_percent::Float64: 零序磁化阻抗与短路阻抗比
- si0_hv_partial::Float64: 高压侧零序短路阻抗分布
- vector_group::String: 接线组别
- tap_side::String: 分接开关位置（高压侧或低压侧）
- tap_step_percent::Float64: 电压幅值调节步长 [%]
- tap_step_degree::Float64: 电压相角调节步长
- parallel::Int: 并联变压器数量
- max_loading_percent::Float64: 相对于额定容量的最大负载率
- df::Float64: 降容系数（0到1之间）
- in_service::Bool: 运行状态
- oltc::Bool: 是否有有载调压
- power_station_unit::Bool: 是否为电站变压器
- tap2_side::String: 第二分接开关位置
- tap2_step_percent::Float64: 第二分接开关电压幅值调节步长 [%]
- tap2_step_degree::Float64: 第二分接开关电压相角调节步长
- leakage_resistance_ratio_hv::Float64: 高压侧漏电阻比例
- leakage_reactance_ratio_hv::Float64: 高压侧漏电抗比例
"""
struct Transformer
    name::Union{String, Nothing}
    sn_mva::Float64
    vn_hv_kv::Float64
    vn_lv_kv::Float64
    vk_percent::Float64
    vkr_percent::Float64
    pfe_kw::Float64
    i0_percent::Float64
    vk0_percent::Float64
    vkr0_percent::Float64
    mag0_percent::Float64
    si0_hv_partial::Float64
    vector_group::String
    tap_side::String
    tap_step_percent::Float64
    tap_step_degree::Float64
    parallel::Int
    max_loading_percent::Float64
    df::Float64
    in_service::Bool
    oltc::Bool
    power_station_unit::Bool
    tap2_side::String
    tap2_step_percent::Float64
    tap2_step_degree::Float64
    leakage_resistance_ratio_hv::Float64
    leakage_reactance_ratio_hv::Float64
end

function validate_transformer_parameters(
    sn_mva::Float64,
    vn_hv_kv::Float64,
    vn_lv_kv::Float64,
    vk_percent::Float64,
    vkr_percent::Float64,
    pfe_kw::Float64,
    i0_percent::Float64,
    vk0_percent::Float64,
    vkr0_percent::Float64,
    mag0_percent::Float64,
    si0_hv_partial::Float64,
    vector_group::String,
    tap_side::String,
    tap_step_percent::Float64,
    tap_step_degree::Float64,
    parallel::Int,
    max_loading_percent::Float64,
    df::Float64,
    in_service::Bool,
    oltc::Bool,
    power_station_unit::Bool,
    tap2_side::String,
    tap2_step_percent::Float64,
    tap2_step_degree::Float64,
    leakage_resistance_ratio_hv::Float64,
    leakage_reactance_ratio_hv::Float64,
    name::Union{String, Nothing}=nothing
)
    # 验证正值参数
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end
    if vn_hv_kv <= 0
        throw(ArgumentError("vn_hv_kv必须大于0"))
    end
    if vn_lv_kv <= 0
        throw(ArgumentError("vn_lv_kv必须大于0"))
    end
    if vk_percent <= 0
        throw(ArgumentError("vk_percent必须大于0"))
    end

    # 验证非负值参数
    if vkr_percent < 0
        throw(ArgumentError("vkr_percent必须大于等于0"))
    end
    if pfe_kw < 0
        throw(ArgumentError("pfe_kw必须大于等于0"))
    end
    if i0_percent < 0
        throw(ArgumentError("i0_percent必须大于等于0"))
    end
    if vk0_percent < 0
        throw(ArgumentError("vk0_percent必须大于等于0"))
    end
    if vkr0_percent < 0
        throw(ArgumentError("vkr0_percent必须大于等于0"))
    end
    if mag0_percent < 0
        throw(ArgumentError("mag0_percent必须大于等于0"))
    end
    if si0_hv_partial < 0
        throw(ArgumentError("si0_hv_partial必须大于等于0"))
    end

    # 验证vector_group
    valid_vector_groups = ["Dyn", "Yyn", "Yzn", "YNyn"]
    if !(vector_group in valid_vector_groups)
        throw(ArgumentError("vector_group必须是以下之一: $(valid_vector_groups)"))
    end

    # 验证tap相关参数
    if tap_step_percent <= 0
        throw(ArgumentError("tap_step_percent必须大于0"))
    end
    if tap_step_degree < 0
        throw(ArgumentError("tap_step_degree必须大于等于0"))
    end
    if tap2_step_percent <= 0
        throw(ArgumentError("tap2_step_percent必须大于0"))
    end
    if tap2_step_degree < 0
        throw(ArgumentError("tap2_step_degree必须大于等于0"))
    end

    # 验证其他参数
    if parallel <= 0
        throw(ArgumentError("parallel必须大于0"))
    end
    if max_loading_percent <= 0
        throw(ArgumentError("max_loading_percent必须大于0"))
    end
    if df <= 0 || df >= 1
        throw(ArgumentError("df必须在0到1之间"))
    end

    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end
    if !isa(oltc, Bool)
        throw(ArgumentError("oltc必须是布尔值"))
    end
    if !isa(power_station_unit, Bool)
        throw(ArgumentError("power_station_unit必须是布尔值"))
    end

    return true
end

"""
三绕组变压器的数据结构
- name::Union{String, Nothing}: 变压器名称（可选）
- vn_mv_kv::Float64: 中压侧额定电压 [kV]
- vn_lv_kv::Float64: 低压侧额定电压 [kV]
- sn_hv_mva::Float64: 高压侧额定视在功率 [MVA]
- sn_mv_mva::Float64: 中压侧额定视在功率 [MVA]
- sn_lv_mva::Float64: 低压侧额定视在功率 [MVA]
- vk_hv_percent::Float64: 高压到中压的短路电压 [%]
- vk_mv_percent::Float64: 中压到低压的短路电压 [%]
- vk_lv_percent::Float64: 高压到低压的短路电压 [%]
- vkr_hv_percent::Float64: 高压到中压短路电压的实部 [%]
- vkr_mv_percent::Float64: 中压到低压短路电压的实部 [%]
- vkr_lv_percent::Float64: 高压到低压短路电压的实部 [%]
- pfe_kw::Float64: 铁损 [kW]
- i0_percent::Float64: 空载损耗 [%]
- tap_side::String: 分接开关位置（高压侧、中压侧或低压侧）
- tap_step_percent::Float64: 调压步长 [%]
- in_service::Bool: 运行状态
"""
struct ThreeWindingTransformer
    name::Union{String, Nothing}
    vn_mv_kv::Float64
    vn_lv_kv::Float64
    sn_hv_mva::Float64
    sn_mv_mva::Float64
    sn_lv_mva::Float64
    vk_hv_percent::Float64
    vk_mv_percent::Float64
    vk_lv_percent::Float64
    vkr_hv_percent::Float64
    vkr_mv_percent::Float64
    vkr_lv_percent::Float64
    pfe_kw::Float64
    i0_percent::Float64
    tap_side::String
    tap_step_percent::Float64
    in_service::Bool
end

function validate_three_winding_transformer_parameters(
    vn_mv_kv::Float64,
    vn_lv_kv::Float64,
    sn_hv_mva::Float64,
    sn_mv_mva::Float64,
    sn_lv_mva::Float64,
    vk_hv_percent::Float64,
    vk_mv_percent::Float64,
    vk_lv_percent::Float64,
    vkr_hv_percent::Float64,
    vkr_mv_percent::Float64,
    vkr_lv_percent::Float64,
    pfe_kw::Float64,
    i0_percent::Float64,
    tap_side::String,
    tap_step_percent::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证正值参数
    if vn_mv_kv <= 0
        throw(ArgumentError("vn_mv_kv必须大于0"))
    end
    if vn_lv_kv <= 0
        throw(ArgumentError("vn_lv_kv必须大于0"))
    end
    if sn_hv_mva <= 0
        throw(ArgumentError("sn_hv_mva必须大于0"))
    end
    if sn_mv_mva <= 0
        throw(ArgumentError("sn_mv_mva必须大于0"))
    end
    if sn_lv_mva <= 0
        throw(ArgumentError("sn_lv_mva必须大于0"))
    end
    if vk_hv_percent <= 0
        throw(ArgumentError("vk_hv_percent必须大于0"))
    end
    if vk_mv_percent <= 0
        throw(ArgumentError("vk_mv_percent必须大于0"))
    end
    if vk_lv_percent <= 0
        throw(ArgumentError("vk_lv_percent必须大于0"))
    end

    # 验证非负值参数
    if vkr_hv_percent < 0
        throw(ArgumentError("vkr_hv_percent必须大于等于0"))
    end
    if vkr_mv_percent < 0
        throw(ArgumentError("vkr_mv_percent必须大于等于0"))
    end
    if vkr_lv_percent < 0
        throw(ArgumentError("vkr_lv_percent必须大于等于0"))
    end
    if pfe_kw < 0
        throw(ArgumentError("pfe_kw必须大于等于0"))
    end
    if i0_percent < 0
        throw(ArgumentError("i0_percent必须大于等于0"))
    end

    # 验证tap_side
    if !(tap_side in ["hv", "mv", "lv"])
        throw(ArgumentError("tap_side必须是以下之一: [\"hv\", \"mv\", \"lv\"]"))
    end

    # 验证tap_step_percent
    if tap_step_percent <= 0
        throw(ArgumentError("tap_step_percent必须大于0"))
    end

    # 验证in_service
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
发电机的数据结构
- name::Union{String, Nothing}: 发电机名称（可选）
- gen_type::String: 发电机类型（同步或异步）
- p_mw::Float64: 发电机有功功率 [MW]
- sn_mva::Float64: 发电机额定容量 [MVA]
- scaling::Float64: 有功功率的缩放因子
- xdss_pu::Float64: 发电机次暂态电抗（标幺值）
- rdss_ohm::Float64: 发电机次暂态电阻 [Ω]
- cos_phi::Float64: 发电机额定功率因数
- in_service::Bool: 运行状态
"""
struct Generator
    name::Union{String, Nothing}
    gen_type::String
    p_mw::Float64
    sn_mva::Float64
    scaling::Float64
    xdss_pu::Float64
    rdss_ohm::Float64
    cos_phi::Float64
    in_service::Bool
end

function validate_generator_parameters(
    gen_type::String,
    p_mw::Float64,
    sn_mva::Float64,
    scaling::Float64,
    xdss_pu::Float64,
    rdss_ohm::Float64,
    cos_phi::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证gen_type
    if !(gen_type in ["sync", "async"])
        throw(ArgumentError("gen_type必须是以下之一: [\"sync\", \"async\"]"))
    end

    # 验证正值参数
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end
    if xdss_pu <= 0
        throw(ArgumentError("xdss_pu必须大于0"))
    end
    if rdss_ohm <= 0
        throw(ArgumentError("rdss_ohm必须大于0"))
    end

    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
并联电抗器的数据结构
- name::Union{String, Nothing}: 并联电抗器名称（可选）
- p_mw::Float64: 在1.0标幺值电压下的有功功率 [MW]
- vn_kv::Float64: 额定电压 [kV]
- step::Int: 分接头位置
- in_service::Bool: 运行状态
"""
struct Shunt
    name::Union{String, Nothing}
    p_mw::Float64
    vn_kv::Float64
    step::Int
    in_service::Bool
end

function validate_shunt_parameters(
    p_mw::Float64,
    vn_kv::Float64,
    step::Int,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证非负值参数
    if p_mw < 0
        throw(ArgumentError("p_mw必须大于等于0"))
    end

    # 验证正值参数
    if vn_kv <= 0
        throw(ArgumentError("vn_kv必须大于0"))
    end

    # 验证step
    if step < 1
        throw(ArgumentError("step必须大于等于1"))
    end

    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
阻抗元件的数据结构
- name::Union{String, Nothing}: 阻抗元件名称（可选）
- rft_pu::Float64: 从'from'母线到'to'母线的电阻 [标幺值]
- xft_pu::Float64: 从'from'母线到'to'母线的电抗 [标幺值]
- rtf_pu::Float64: 从'to'母线到'from'母线的电阻 [标幺值]
- xtf_pu::Float64: 从'to'母线到'from'母线的电抗 [标幺值]
- rft0_pu::Float64: 从'from'母线到'to'母线的零序电阻 [标幺值]
- xft0_pu::Float64: 从'from'母线到'to'母线的零序电抗 [标幺值]
- rtf0_pu::Float64: 从'to'母线到'from'母线的零序电阻 [标幺值]
- xtf0_pu::Float64: 从'to'母线到'from'母线的零序电抗 [标幺值]
- gf_pu::Float64: 'from'母线端的电导 [标幺值]
- bf_pu::Float64: 'from'母线端的电纳 [标幺值]
- gt_pu::Float64: 'to'母线端的电导 [标幺值]
- bt_pu::Float64: 'to'母线端的电纳 [标幺值]
- gf0_pu::Float64: 'from'母线端的零序电导 [标幺值]
- bf0_pu::Float64: 'from'母线端的零序电纳 [标幺值]
- gt0_pu::Float64: 'to'母线端的零序电导 [标幺值]
- bt0_pu::Float64: 'to'母线端的零序电纳 [标幺值]
- sn_mva::Float64: 标幺值计算的基准视在功率 [MVA]
- in_service::Bool: 运行状态
"""
struct Impedance
    name::Union{String, Nothing}
    rft_pu::Float64
    xft_pu::Float64
    rtf_pu::Float64
    xtf_pu::Float64
    rft0_pu::Float64
    xft0_pu::Float64
    rtf0_pu::Float64
    xtf0_pu::Float64
    gf_pu::Float64
    bf_pu::Float64
    gt_pu::Float64
    bt_pu::Float64
    gf0_pu::Float64
    bf0_pu::Float64
    gt0_pu::Float64
    bt0_pu::Float64
    sn_mva::Float64
    in_service::Bool
end

function validate_impedance_parameters(
    rft_pu::Float64,
    xft_pu::Float64,
    rtf_pu::Float64,
    xtf_pu::Float64,
    rft0_pu::Float64,
    xft0_pu::Float64,
    rtf0_pu::Float64,
    xtf0_pu::Float64,
    gf_pu::Float64,
    bf_pu::Float64,
    gt_pu::Float64,
    bt_pu::Float64,
    gf0_pu::Float64,
    bf0_pu::Float64,
    gt0_pu::Float64,
    bt0_pu::Float64,
    sn_mva::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证正值参数
    if rft_pu <= 0
        throw(ArgumentError("rft_pu必须大于0"))
    end
    if xft_pu <= 0
        throw(ArgumentError("xft_pu必须大于0"))
    end
    if rtf_pu <= 0
        throw(ArgumentError("rtf_pu必须大于0"))
    end
    if xtf_pu <= 0
        throw(ArgumentError("xtf_pu必须大于0"))
    end
    if rft0_pu <= 0
        throw(ArgumentError("rft0_pu必须大于0"))
    end
    if xft0_pu <= 0
        throw(ArgumentError("xft0_pu必须大于0"))
    end
    if rtf0_pu <= 0
        throw(ArgumentError("rtf0_pu必须大于0"))
    end
    if xtf0_pu <= 0
        throw(ArgumentError("xtf0_pu必须大于0"))
    end
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end

    # 验证特定下限的参数
    if gf_pu <= 1
        throw(ArgumentError("gf_pu必须大于1"))
    end
    if bf_pu <= 2
        throw(ArgumentError("bf_pu必须大于2"))
    end
    if gt_pu <= 3
        throw(ArgumentError("gt_pu必须大于3"))
    end
    if bt_pu <= 4
        throw(ArgumentError("bt_pu必须大于4"))
    end
    if gf0_pu <= 1
        throw(ArgumentError("gf0_pu必须大于1"))
    end
    if bf0_pu <= 2
        throw(ArgumentError("bf0_pu必须大于2"))
    end
    if gt0_pu <= 3
        throw(ArgumentError("gt0_pu必须大于3"))
    end
    if bt0_pu <= 4
        throw(ArgumentError("bt0_pu必须大于4"))
    end

    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
Ward等值的数据结构
- name::Union{String, Nothing}: Ward等值的名称（可选）
- in_service::Bool: 运行状态
"""
struct Ward
    name::Union{String, Nothing}
    in_service::Bool
end

function validate_ward_parameters(
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
扩展Ward等值的数据结构
- name::Union{String, Nothing}: 扩展Ward等值的名称（可选）
- r_ohm::Float64: 电压源的内部电阻 [欧姆]
- x_ohm::Float64: 电压源的内部电抗 [欧姆]
- vm_pu::Float64: 电压源设定值 [标幺值]
- in_service::Bool: 运行状态
"""
struct ExtendedWard
    name::Union{String, Nothing}
    r_ohm::Float64
    x_ohm::Float64
    vm_pu::Float64
    in_service::Bool
end

function validate_extended_ward_parameters(
    r_ohm::Float64,
    x_ohm::Float64,
    vm_pu::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证正值参数
    if r_ohm <= 0
        throw(ArgumentError("r_ohm必须大于0"))
    end
    if x_ohm <= 0
        throw(ArgumentError("x_ohm必须大于0"))
    end
    if vm_pu <= 0
        throw(ArgumentError("vm_pu必须大于0"))
    end

    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
直流输电线路的数据结构
- name::Union{String, Nothing}: 直流线路名称（可选）
- p_mw::Float64: 从'from_bus'传输到'to_bus'的有功功率 [MW]
- loss_percent::Float64: 有功功率传输的相对损耗百分比 [%]
- loss_mw::Float64: 总传输损耗 [MW]
- vm_from_pu::Float64: 起始母线电压设定值 [标幺值]
- vm_to_pu::Float64: 终止母线电压设定值 [标幺值]
- max_p_mw::Float64: 最大有功功率传输 [MW]
- in_service::Bool: 运行状态
"""
struct DcLine
    name::Union{String, Nothing}
    p_mw::Float64
    loss_percent::Float64
    loss_mw::Float64
    vm_from_pu::Float64
    vm_to_pu::Float64
    max_p_mw::Float64
    in_service::Bool
end

function validate_dc_line_parameters(
    p_mw::Float64,
    loss_percent::Float64,
    loss_mw::Float64,
    vm_from_pu::Float64,
    vm_to_pu::Float64,
    max_p_mw::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证正值参数
    if p_mw <= 0
        throw(ArgumentError("p_mw必须大于0"))
    end
    if loss_percent <= 0
        throw(ArgumentError("loss_percent必须大于0"))
    end
    if loss_mw <= 0
        throw(ArgumentError("loss_mw必须大于0"))
    end
    if vm_from_pu <= 0
        throw(ArgumentError("vm_from_pu必须大于0"))
    end
    if vm_to_pu <= 0
        throw(ArgumentError("vm_to_pu必须大于0"))
    end
    if max_p_mw <= 0
        throw(ArgumentError("max_p_mw必须大于0"))
    end

    # 验证布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
测量设备的数据结构
- name::Union{String, Nothing}: 测量设备名称（可选）
- measurement_type::String: 定义测量的物理量类型
- element_type::String: 定义安装测量设备的元件类型
- bus::Int: 定义测量设备安装的母线。对于线路或变压器测量，它定义了测量设备安装的一侧（from_bus或to_bus）
- element::Union{Int, Nothing}: 如果element_type是"line"或"transformer"，element是相关元件的索引。对于"bus"测量，它是Nothing
"""
struct Measurement
    name::Union{String, Nothing}
    measurement_type::String
    element_type::String
    bus::Int
    element::Union{Int, Nothing}
end

function validate_measurement_parameters(
    measurement_type::String,
    element_type::String,
    bus::Int,
    element::Union{Int, Nothing}=nothing,
    name::Union{String, Nothing}=nothing
)
    # 验证字符串参数不为空
    if isempty(measurement_type)
        throw(ArgumentError("measurement_type不能为空"))
    end
    if isempty(element_type)
        throw(ArgumentError("element_type不能为空"))
    end

    # 验证bus为正整数
    if bus <= 0
        throw(ArgumentError("bus必须为正整数"))
    end

    # 验证element（如果提供）为正整数
    if !isnothing(element) && element <= 0
        throw(ArgumentError("如果提供element，它必须为正整数"))
    end

    return true
end

"""
储能设备的数据结构
- name::Union{String, Nothing}: 储能设备名称（可选）
- p_mw::Float64: 储能设备的瞬时实功率（充电为正，放电为负）[MW]
- sn_mva::Float64: 储能设备的额定功率 [MVA]
- scaling::Float64: 有功和无功功率的缩放因子
- soc_percent::Float64: 储能设备的荷电状态 [%]
- in_service::Bool: 储能设备的运行状态
"""
struct Storage
    name::Union{String, Nothing}
    p_mw::Float64
    sn_mva::Float64
    scaling::Float64
    soc_percent::Float64
    in_service::Bool
end

function validate_storage_parameters(
    p_mw::Float64,
    sn_mva::Float64,
    scaling::Float64,
    soc_percent::Float64,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证额定功率必须为正
    if sn_mva <= 0
        throw(ArgumentError("sn_mva必须大于0"))
    end

    # 验证缩放因子必须非负
    if scaling < 0
        throw(ArgumentError("scaling必须大于等于0"))
    end

    # 验证运行状态必须是布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
静止无功补偿器(SVC)的数据结构
- name::Union{String, Nothing}: SVC名称（可选）
- x_l_ohm::Float64: SVC的电抗器分量阻抗 [Ω]
- x_cvar_ohm::Float64: SVC的固定电容器分量阻抗 [Ω]
- thyristor_firing_angle_degree::Float64: SVC的晶闸管触发角度 [度]
- controllable::Bool: 是否作为主动控制元件或固定并联阻抗
- in_service::Bool: SVC的运行状态
- min_angle_degree::Float64: 晶闸管触发角度的最小值 [度]
- max_angle_degree::Float64: 晶闸管触发角度的最大值 [度]
"""
struct StaticVarCompensator
    name::Union{String, Nothing}
    x_l_ohm::Float64
    x_cvar_ohm::Float64
    thyristor_firing_angle_degree::Float64
    controllable::Bool
    in_service::Bool
    min_angle_degree::Float64
    max_angle_degree::Float64
end

function validate_svc_parameters(
    x_l_ohm::Float64,
    x_cvar_ohm::Float64,
    thyristor_firing_angle_degree::Float64,
    controllable::Bool,
    in_service::Bool,
    min_angle_degree::Float64,
    max_angle_degree::Float64,
    name::Union{String, Nothing}=nothing
)
    # 验证电抗器分量阻抗必须非负
    if x_l_ohm < 0
        throw(ArgumentError("x_l_ohm必须大于等于0"))
    end

    # 验证最小触发角度必须大于等于90度
    if min_angle_degree < 90
        throw(ArgumentError("min_angle_degree必须大于等于90度"))
    end

    # 验证最大触发角度必须大于最小触发角度
    if max_angle_degree < min_angle_degree
        throw(ArgumentError("max_angle_degree必须大于min_angle_degree"))
    end

    # 验证控制模式必须是布尔值
    if !isa(controllable, Bool)
        throw(ArgumentError("controllable必须是布尔值"))
    end

    # 验证运行状态必须是布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
可控串联电容器(TCSC)的数据结构
- name::Union{String, Nothing}: TCSC名称（可选）
- x_l_ohm::Float64: TCSC的电抗器分量阻抗 [Ω]
- x_cvar_ohm::Float64: TCSC的固定电容器分量阻抗 [Ω]
- thyristor_firing_angle_degree::Float64: TCSC的晶闸管触发角度 [度]
- controllable::Bool: 是否作为主动控制元件或固定串联阻抗
- in_service::Bool: TCSC的运行状态
- min_angle_degree::Float64: 晶闸管触发角度的最小值 [度]
- max_angle_degree::Float64: 晶闸管触发角度的最大值 [度]
"""
struct ThyristorControlledSeriesCap
    name::Union{String, Nothing}
    x_l_ohm::Float64
    x_cvar_ohm::Float64
    thyristor_firing_angle_degree::Float64
    controllable::Bool
    in_service::Bool
    min_angle_degree::Float64
    max_angle_degree::Float64
end

function validate_tcsc_parameters(
    x_l_ohm::Float64,
    x_cvar_ohm::Float64,
    thyristor_firing_angle_degree::Float64,
    controllable::Bool,
    in_service::Bool,
    min_angle_degree::Float64,
    max_angle_degree::Float64,
    name::Union{String, Nothing}=nothing
)
    # 验证电抗器分量阻抗必须非负
    if x_l_ohm < 0
        throw(ArgumentError("x_l_ohm必须大于等于0"))
    end

    # 验证最小触发角度必须大于等于90度
    if min_angle_degree < 90
        throw(ArgumentError("min_angle_degree必须大于等于90度"))
    end

    # 验证最大触发角度必须大于最小触发角度
    if max_angle_degree < min_angle_degree
        throw(ArgumentError("max_angle_degree必须大于min_angle_degree"))
    end

    # 验证控制模式必须是布尔值
    if !isa(controllable, Bool)
        throw(ArgumentError("controllable必须是布尔值"))
    end

    # 验证运行状态必须是布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
静止同步补偿器(SSC)的数据结构
- name::Union{String, Nothing}: SSC名称（可选）
- r_ohm::Float64: SSC的耦合变压器电阻分量 [Ω]
- x_ohm::Float64: SSC的耦合变压器电抗分量 [Ω]
- controllable::Bool: 是否作为主动控制元件或固定并联阻抗
- in_service::Bool: SSC的运行状态
"""
struct StaticSynchronousCompensator
    name::Union{String, Nothing}
    r_ohm::Float64
    x_ohm::Float64
    controllable::Bool
    in_service::Bool
end

function validate_ssc_parameters(
    r_ohm::Float64,
    x_ohm::Float64,
    controllable::Bool,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证电阻分量必须非负
    if r_ohm < 0
        throw(ArgumentError("r_ohm必须大于等于0"))
    end

    # 验证控制模式必须是布尔值
    if !isa(controllable, Bool)
        throw(ArgumentError("controllable必须是布尔值"))
    end

    # 验证运行状态必须是布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
电压源换流器(VSC)的数据结构
- name::Union{String, Nothing}: VSC名称（可选）
- r_ohm::Float64: 耦合变压器电阻 [Ω]
- x_ohm::Float64: 耦合变压器电抗 [Ω]
- controllable::Bool: 是否作为主动控制元件
- in_service::Bool: VSC的运行状态
"""
struct VoltageSourceConverter
    name::Union{String, Nothing}
    r_ohm::Float64
    x_ohm::Float64
    controllable::Bool
    in_service::Bool
end

function validate_vsc_parameters(
    r_ohm::Float64,
    x_ohm::Float64,
    controllable::Bool,
    in_service::Bool,
    name::Union{String, Nothing}=nothing
)
    # 验证电阻必须非负
    if r_ohm < 0
        throw(ArgumentError("r_ohm必须大于等于0"))
    end

    # 验证控制模式必须是布尔值
    if !isa(controllable, Bool)
        throw(ArgumentError("controllable必须是布尔值"))
    end

    # 验证运行状态必须是布尔值
    if !isa(in_service, Bool)
        throw(ArgumentError("in_service必须是布尔值"))
    end

    return true
end

"""
电力网络数据结构
- name::Union{String, Nothing}: 网络名称（可选）
- baseMVA::Float64: 基准容量 [MVA]
"""
struct Network
    name::Union{String, Nothing}
    baseMVA::Float64
end

function validate_network_parameters(
    baseMVA::Float64,
    name::Union{String, Nothing}=nothing
)
    # 验证基准容量必须为正数
    if baseMVA <= 0
        throw(ArgumentError("baseMVA必须大于0"))
    end

    return true
end

