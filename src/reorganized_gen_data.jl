# 定义常量默认值
DEFAULT_GEN_VALUES = Dict(
    :QMAX => 700,
    :QMIN => -20,
    :MBASE => 100,
    :STATUS => 1,
    :PMAX => 1000,
    :PMIN => 0,
    :VG_DEFAULT => 1.0
)

# 通用的初始化函数
function initialize_base_generator_matrix(n_rows::Int, idx_gen_constants)::Matrix{Float64}
    # 解构索引常量
    GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, STATUS, PMAX, PMIN, PC1,
     PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP10, RAMP30, 
     RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
      COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN = idx_gen_constants
    gen = zeros(n_rows, 26)
    
    # 设置默认值
    gen[:, QMAX] .= DEFAULT_GEN_VALUES[:QMAX]
    gen[:, QMIN] .= DEFAULT_GEN_VALUES[:QMIN]
    gen[:, MBASE] .= DEFAULT_GEN_VALUES[:MBASE]
    gen[:, STATUS] .= DEFAULT_GEN_VALUES[:STATUS]
    gen[:, PMAX] .= DEFAULT_GEN_VALUES[:PMAX]
    gen[:, PMIN] .= DEFAULT_GEN_VALUES[:PMIN]
    
    # 将其余参数设为0
    zero_cols = [PC1, PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, 
                RAMP_AGC, RAMP10, RAMP30, RAMP_Q, APF]
    gen[:, zero_cols] .= 0
    
    return gen
end

function initialize_generator_matrix(
    gen_data::DataFrame, 
    dict_bus::Dict, 
    bus::Matrix{Float64}
)::Matrix{Float64}
    # 获取索引
    Gen_connected_element, Gen_inservice, Gen_controlmode, Gen_power_rating,
    Gen_apparent_power_rating, Gen_voltage = PowerFlow.gen_idx()
    
    # 获取发电机索引常量
    idx_gen_constants = PowerFlow.idx_gen()
    GEN_BUS, PG, QG = idx_gen_constants[1:3]
    VG = idx_gen_constants[6]
    
    # 获取母线索引常量
    bus_constants = PowerFlow.idx_bus()
    BASEKV = bus_constants[14]
    
    # 初始化基础矩阵
    gen = initialize_base_generator_matrix(size(gen_data, 1), idx_gen_constants)
    
    # 更新总线编号
    if !isempty(gen_data)
        bus_indices = map(k -> dict_bus[k], gen_data[:, Gen_connected_element])
        gen[:, GEN_BUS] .= bus_indices
        # 设置功率相关参数
        gen[:, PG] .= gen_data[:, Gen_power_rating]
        gen[:, QG] .= @. sqrt(gen_data[:, Gen_apparent_power_rating]^2 - gen_data[:, Gen_power_rating]^2)
        
        # 设置电压
        base_kv = bus[map(k -> dict_bus[k], gen_data[:, Gen_connected_element]), BASEKV]
        gen[:, VG] .= gen_data[:, Gen_voltage] ./ base_kv
    else
        gen = zeros(0, 26)
    end
    # bus_indices = map(k -> dict_bus[k], gen_data[:, Gen_connected_element])
    # gen[:, GEN_BUS] .= bus_indices
    
    
    
    return gen
end

function initialize_utility_generator_matrix(
    Utility_data::DataFrame, 
    dict_bus::Dict
)::Matrix{Float64}
    # 获取索引
    (Utility_EquipmentID,Utility_connected_ID,Utility_Inservice,Utility_Voltage,Utility_control_mode)=PowerFlow.utility_idx()#电网索引
    
    # 获取发电机索引常量
    idx_gen_constants = idx_gen()
    GEN_BUS = idx_gen_constants[1]
    VG = idx_gen_constants[6]
    
    # 初始化基础矩阵
    gen_utility = initialize_base_generator_matrix(size(Utility_data, 1), idx_gen_constants)
    
    # 更新总线编号
    bus_indices = map(k -> dict_bus[k], Utility_data[:, Utility_connected_ID])
    gen_utility[:, GEN_BUS] .= bus_indices
    
    # 设置电压
    gen_utility[:, VG] .= DEFAULT_GEN_VALUES[:VG_DEFAULT]
    
    return gen_utility
end

function update_generator_bus(gen::Matrix{Float64}, 
    dict_bus::Dict)::Matrix{Float64}
    # 获取发电机索引常量
    idx_gen_constants = idx_gen()
    GEN_BUS = idx_gen_constants[1]

    # 更新总线编号
    bus_indices = map(k -> dict_bus[k], gen[:, GEN_BUS])
    gen[:, GEN_BUS] .= bus_indices

    return gen
end


# 合并发电机矩阵
function combine_generator_matrices(
    gen::Matrix{Float64}, 
    gen_utility::Matrix{Float64}
)::Matrix{Float64}
    vcat(gen, gen_utility)
end
