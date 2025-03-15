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
    (FBUS, TBUS, R, X, B, RATEA, RATEB, RATEC, RATIO, ANGLE, STATUS, ANGMIN,
     ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF, MU_ST, MU_ANGMIN, MU_ANGMAX, LAMBDA, SW_TIME, RP_TIME, BR_TYPE, BR_AREA) = PowerFlow.idx_brch()
    
    (DC_IMPEDANCE_ID, DC_IMPEDANCE_INSERVICE, DC_IMPEDANCE_F_ELEMENT,
     DC_IMPEDANCE_T_ELEMENT, DC_IMPEDANCE_R, DC_IMPEDANCE_L) = PowerFlow.dcimp_idx()
    
    (DCBUS_ID, DCBUS_V, DCBUS_INSERVICE) = PowerFlow.dcbus_idx()
    (Dccable_ID,Dccable_inservice,Dccable_state,Dccable_felement,Dccable_telement,
    Dccable_length,Dccable_length_unit,Dccable_ohmsper,Dccable_ohmsper_unit,Dccable_rposvalue,Dccable_xposvalue)=PowerFlow.dccable_idx()

    # 初始化结果数组
    all_branches = []
    
    # 处理直流阻抗（如果存在）
    if !isempty(DC_impedance)
        # 筛选在运行的直流阻抗
        DC_impedance_active = filter(row -> row[DC_IMPEDANCE_INSERVICE] != 0, DC_impedance)
        
        # 清理缺失数据
        DC_impedance_active = filter(row -> !ismissing(row[DC_IMPEDANCE_F_ELEMENT]) && 
                                      !ismissing(row[DC_IMPEDANCE_T_ELEMENT]), 
                                 DC_impedance_active)
        
        if !isempty(DC_impedance_active)
            # 初始化直流阻抗支路矩阵
            branch_DC_impedance = zeros(size(DC_impedance_active, 1), 14)
            
            # 设置起始和终止母线
            branch_DC_impedance[:, FBUS] = map(k -> Dict_busdc[k], DC_impedance_active[:, DC_IMPEDANCE_F_ELEMENT])
            branch_DC_impedance[:, TBUS] = map(k -> Dict_busdc[k], DC_impedance_active[:, DC_IMPEDANCE_T_ELEMENT])
            
            # 设置阻抗参数
            branch_DC_impedance[:, R] = parse.(Float64, DC_impedance_active[:, DC_IMPEDANCE_R])
            branch_DC_impedance[:, X] = parse.(Float64, DC_impedance_active[:, DC_IMPEDANCE_L])
            branch_DC_impedance[:, B] = zeros(size(DC_impedance_active, 1))
            
            # 设置额定值和状态
            RATE_VALUE = 100.0
            branch_DC_impedance[:, RATEA] .= RATE_VALUE
            branch_DC_impedance[:, RATEB] .= RATE_VALUE
            branch_DC_impedance[:, RATEC] .= RATE_VALUE
            branch_DC_impedance[:, RATIO] .= 0.0
            branch_DC_impedance[:, ANGLE] .= 0.0
            branch_DC_impedance[:, STATUS] .= 1.0
            branch_DC_impedance[:, ANGMIN] .= -180.0
            branch_DC_impedance[:, ANGMAX] .= 180.0
            
            # 标准化阻抗值（转换为标幺值）
            dc_impedance_kv = 0.001 .* parse.(Float64,DCbus[Int.(branch_DC_impedance[:, FBUS]), DCBUS_V])
            
            branch_DC_impedance[:, R] = 2.0 * branch_DC_impedance[:, R] .* baseMVA .* inv.(dc_impedance_kv.^2)
            branch_DC_impedance[:, X] = 2.0 * branch_DC_impedance[:, X] .* baseMVA .* inv.(dc_impedance_kv.^2)
            branch_DC_impedance[:, B] = 2.0 * branch_DC_impedance[:, B] ./ (baseMVA .* inv.(dc_impedance_kv.^2))
            
            push!(all_branches, branch_DC_impedance)
        end
    end
    
    # 处理直流电缆（如果存在）
    if !isempty(DC_cable)
        # 筛选在运行的直流电缆
        DC_cable_active = filter(row -> row[Dccable_inservice] != 0, DC_cable)
        
        # 清理缺失数据
        DC_cable_active = filter(row -> !ismissing(row[Dccable_felement]) && 
                                 !ismissing(row[Dccable_telement]), 
                              DC_cable_active)
        
        if !isempty(DC_cable_active)
            # 初始化直流电缆支路矩阵
            branch_DC_cable = zeros(size(DC_cable_active, 1), 14)
            
            # 设置起始和终止母线
            branch_DC_cable[:, FBUS] = map(k -> Dict_busdc[k], DC_cable_active[:, Dccable_felement])
            branch_DC_cable[:, TBUS] = map(k -> Dict_busdc[k], DC_cable_active[:, Dccable_telement])
            
            # 设置阻抗参数
            branch_DC_cable[:, R] = parse.(Float64, DC_cable_active[:, Dccable_rposvalue]) .* 
                                    parse.(Float64, DC_cable_active[:, Dccable_length]) ./ 1000
            branch_DC_cable[:, X] = parse.(Float64, DC_cable_active[:, Dccable_xposvalue]) .* 
                                    parse.(Float64, DC_cable_active[:, Dccable_length]) ./ 1000
            branch_DC_cable[:, B] = zeros(size(DC_cable_active, 1))
            
            # 设置额定值和状态
            RATE_VALUE = 100.0
            branch_DC_cable[:, RATEA] .= RATE_VALUE
            branch_DC_cable[:, RATEB] .= RATE_VALUE
            branch_DC_cable[:, RATEC] .= RATE_VALUE
            branch_DC_cable[:, RATIO] .= 0.0
            branch_DC_cable[:, ANGLE] .= 0.0
            branch_DC_cable[:, STATUS] .= 1.0
            branch_DC_cable[:, ANGMIN] .= -180.0
            branch_DC_cable[:, ANGMAX] .= 180.0
            
            # 标准化阻抗值（转换为标幺值）
            dc_cable_kv = 0.001 .* parse.(Float64,DCbus[Int.(branch_DC_cable[:, FBUS]), DCBUS_V])
            
            branch_DC_cable[:, R] = 2.0 * branch_DC_cable[:, R] .* baseMVA .* inv.(dc_cable_kv.^2)
            branch_DC_cable[:, X] = 2.0 * branch_DC_cable[:, X] .* baseMVA .* inv.(dc_cable_kv.^2)
            branch_DC_cable[:, B] = 2.0 * branch_DC_cable[:, B] ./ (baseMVA .* inv.(dc_cable_kv.^2))
            
            push!(all_branches, branch_DC_cable)
        end
    end
    
    # 添加电池支路（如果存在）
    if !isempty(battery_branches) && size(battery_branches, 1) > 0
        push!(all_branches, battery_branches)
    end
    
    # 合并所有支路
    if isempty(all_branches)
        # 如果没有任何支路，返回空矩阵
        return zeros(0, 14)
    else
        # 合并所有支路
        return vcat(all_branches...)
    end
end
