"""
处理直流支路数据并进行标准化

参数:
- DC_impedance::DataFrame: 直流阻抗数据
- DC_cable::DataFrame: 直流电缆数据
- battery_branches::Matrix{Float64}: 电池支路数据
- DCbus::DataFrame: 直流母线数据
- Dict_busdc::Dict{Any,Float64}: 直流母线映射字典（键为Any类型，值为Float64类型）
- baseMVA::Float64: 基准功率

返回:
- Matrix{Float64}: 处理后的直流支路数据
"""
function process_dcbranch_data(DC_impedance::DataFrame,
                             DC_cable::DataFrame,
                             battery_branches::Matrix{Float64},
                             DCbus::DataFrame,
                             Dict_busdc::Dict{Any,Float64},
                             baseMVA::Float64)::Matrix{Float64}
    
    # 获取索引常量
    (FBUS, TBUS, R, X, B, RATEA, RATEB, RATEC, RATIO, ANGLE, 
    STATUS, ANGMIN, ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF,
     MU_ST, MU_ANGMIN, MU_ANGMAX) = idx_brch()
    
    (DC_IMPEDANCE_ID, DC_IMPEDANCE_INSERVICE, DC_IMPEDANCE_F_ELEMENT,
     DC_IMPEDANCE_T_ELEMENT, DC_IMPEDANCE_R, DC_IMPEDANCE_L) = dcimp_idx()
    
    (DCBUS_ID, DCBUS_V, DCBUS_INSERVICE) = dcbus_idx()

    # 筛选在运行的直流支路
    DC_impedance = filter(row -> row[DC_IMPEDANCE_INSERVICE] != 0, DC_impedance)

    # 清理缺失数据
    DC_impedance = filter(row -> !ismissing(row[DC_IMPEDANCE_F_ELEMENT]) && 
                                !ismissing(row[DC_IMPEDANCE_T_ELEMENT]), 
                         DC_impedance)

    # 初始化直流支路矩阵
    branch_DC_impedance = zeros(size(DC_impedance, 1), 14)

    # 设置起始和终止母线
    branch_DC_impedance[:, FBUS] = map(k -> Dict_busdc[k], DC_impedance[:, DC_IMPEDANCE_F_ELEMENT])
    branch_DC_impedance[:, TBUS] = map(k -> Dict_busdc[k], DC_impedance[:, DC_IMPEDANCE_T_ELEMENT])

    # 设置阻抗参数
    branch_DC_impedance[:, R] = parse.(Float64, DC_impedance[:, DC_IMPEDANCE_R])
    branch_DC_impedance[:, X] = parse.(Float64, DC_impedance[:, DC_IMPEDANCE_L])
    branch_DC_impedance[:, B] = zeros(size(DC_impedance, 1))

    # 设置额定值和状态
    RATE_VALUE = 100.0  # MVA
    for dcbranch in [branch_DC_impedance]
        dcbranch[:, RATEA] .= RATE_VALUE
        dcbranch[:, RATEB] .= RATE_VALUE
        dcbranch[:, RATEC] .= RATE_VALUE
        dcbranch[:, RATIO] .= 0.0
        dcbranch[:, ANGLE] .= 0.0
        dcbranch[:, STATUS] .= 1.0
        dcbranch[:, ANGMIN] .= -180.0
        dcbranch[:, ANGMAX] .= 180.0
    end

    # 标准化阻抗值（转换为标幺值）
    dc_base_voltage = 0.001 * parse(Float64, DCbus[1, DCBUS_V])
    dc_base_z = dc_base_voltage^2 / baseMVA
    
    branch_DC_impedance[:, R] = 2.0 * branch_DC_impedance[:, R] / dc_base_z
    branch_DC_impedance[:, X] = 2.0 * branch_DC_impedance[:, X] / dc_base_z
    branch_DC_impedance[:, B] = 2.0 * branch_DC_impedance[:, B] * dc_base_z

    # 合并所有支路
    dcbranch = [branch_DC_impedance; battery_branches]

    return dcbranch
end
