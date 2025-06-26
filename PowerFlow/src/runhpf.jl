function runhpf(jpc, opt)
    # 准备AC系统数据
    jpc1 = PowerFlow.JPC()

    jpc1.baseMVA = deepcopy(jpc.baseMVA)
    jpc1.busAC = deepcopy(jpc.busAC)
    jpc1.genAC = deepcopy(jpc.genAC)
    jpc1.loadAC = deepcopy(jpc.loadAC)
    jpc1.branchAC = deepcopy(jpc.branchAC)
    jpc1.version = "2"
    
    # 准备DC系统数据
    jpc2 = PowerFlow.JPC()

    jpc2.baseMVA = deepcopy(jpc.baseMVA)
    jpc2.busDC = deepcopy(jpc.busDC)
    jpc2.genDC = deepcopy(jpc.genDC)
    jpc2.loadDC = deepcopy(jpc.loadDC)
    jpc2.branchDC = deepcopy(jpc.branchDC)
    jpc2.pv = deepcopy(jpc.pv)
    jpc2.version = "2"

    # 检查换流器的工作模式
    has_mode_1_2_3 = false
    has_mode_4_5 = false
    
    if !isempty(jpc.converter)
        modes = jpc.converter[:, CONV_MODE]
        has_mode_1_2_3 = any(mode -> mode in [1, 2, 3], modes)
        has_mode_4_5 = any(mode -> mode in [4, 5], modes)
    end
    
    # 根据换流器工作模式决定潮流计算的顺序
    if has_mode_4_5 && !has_mode_1_2_3
        # 只有模式4、5：先运行直流再运行交流
        run_dc_first(jpc, jpc1, jpc2, opt)
    elseif has_mode_1_2_3 && !has_mode_4_5
        # 只有模式1、2、3：先运行交流再运行直流
        run_ac_first(jpc, jpc1, jpc2, opt)
    else
        if !isempty(jpc1.busAC)
            jpc1 = PowerFlow.runpf(jpc1, opt)
        end
        
        if !isempty(jpc2.busDC)
            jpc2 = PowerFlow.rundcpf(jpc2, opt)
        end
    end

    # 创建结果的深拷贝
    result_jpc = deepcopy(jpc)
    
    # 合并结果，包含两个系统的迭代次数和求解状态
    result_jpc.busAC = deepcopy(jpc1.busAC)
    result_jpc.genAC = deepcopy(jpc1.genAC)
    result_jpc.branchAC = deepcopy(jpc1.branchAC)
    result_jpc.loadAC = deepcopy(jpc1.loadAC)
    result_jpc.busDC = deepcopy(jpc2.busDC)
    result_jpc.genDC = deepcopy(jpc2.genDC)
    result_jpc.branchDC = deepcopy(jpc2.branchDC)
    result_jpc.loadDC = deepcopy(jpc2.loadDC)
    result_jpc.pv = deepcopy(jpc2.pv)
    result_jpc.iterationsAC = deepcopy(jpc1.iterationsAC)
    result_jpc.iterationsDC = deepcopy(jpc2.iterationsDC)
    
    if !isempty(jpc2.busDC)
        if jpc1.success && jpc2.success
            result_jpc.success = true
        else
            result_jpc.success = false
        end
    else
        result_jpc.success = jpc1.success
    end

    return result_jpc
end

# 先运行直流再运行交流的函数（适用于CONV_MODE为4、5的情况）
function run_dc_first(jpc, jpc1, jpc2, opt)
    # 运行DC潮流计算
    if !isempty(jpc2.busDC)
        jpc2 = PowerFlow.rundcpf(jpc2, opt)
    end
    
    # 处理工作模式为constant Udc、Qs (CONV_MODE==4)
    converters_udc_qs = filter(row -> row[CONV_MODE] == 4, eachrow(jpc.converter))
    if !isempty(converters_udc_qs)
        converters_index = findall(row -> row[CONV_MODE] == 4, eachrow(jpc.converter))
        for i in eachindex(converters_udc_qs[:, 1])
            conv = converters_udc_qs[i]  # 获取第i行作为当前换流器
            gen_row = findfirst(x -> x == Int(conv[CONV_DCBUS]), jpc2.genDC[:, 1])
            P_dc = - jpc2.genDC[gen_row, PG]

            if P_dc < 0
                P_ac = -P_dc/conv[CONV_EFF]
            else
                P_ac = -P_dc * conv[CONV_EFF]
            end
            # 更新换流器的直流功率
            jpc.converter[converters_index[i], CONV_P_DC] = P_dc
            jpc.converter[converters_index[i], CONV_P_AC] = P_ac

            ac_bus_rows_jpc = findall(x -> x == Int(conv[CONV_ACBUS]), jpc.busAC[:, 1])
            ac_bus_rows_jpc1 = findall(x -> x == Int(conv[CONV_ACBUS]), jpc1.busAC[:, 1])
            jpc.busAC[ac_bus_rows_jpc, PD] .+= P_ac
            jpc1.busAC[ac_bus_rows_jpc1, PD] .+= P_ac

            ac_load_rows_jpc = findall(x -> x == Int(conv[CONV_ACBUS]), jpc.loadAC[:, 2])
            ac_load_rows_jpc1 = findall(x -> x == Int(conv[CONV_ACBUS]), jpc1.loadAC[:, 2])
            jpc.loadAC[ac_load_rows_jpc, LOAD_PD] .+= P_ac
            jpc1.loadAC[ac_load_rows_jpc1, LOAD_PD] .+= P_ac
        end
    end

    # 处理工作模式为constant Udc、Us (CONV_MODE==5)
    converters_udc_us = filter(row -> row[CONV_MODE] == 5, eachrow(jpc.converter))
    if !isempty(converters_udc_us)
        converters_index = findall(row -> row[CONV_MODE] == 5, eachrow(jpc.converter))
        for i in eachindex(converters_udc_us[:, 1])
            conv = converters_udc_us[i]  # 获取第i行作为当前换流器
            gen_row = findfirst(x -> x == Int(conv[CONV_DCBUS]), jpc1.genDC[:, 1])
            P_dc = - jpc2.genDC[gen_row, PG]

            if P_dc < 0
                P_ac = -P_dc/conv[CONV_EFF]
            else
                P_ac = -P_dc * conv[CONV_EFF]
            end
            # 更新换流器的直流功率
            jpc.converter[converters_index[i], CONV_P_DC] = P_dc
            jpc.converter[converters_index[i], CONV_P_AC] = P_ac

            ac_gen_row_jpc = findall(x -> x == Int(conv[CONV_ACBUS]), jpc.genAC[:, 1])
            ac_gen_row_jpc1 = findall(x -> x == Int(conv[CONV_ACBUS]), jpc1.genAC[:, 1])
            jpc.genAC[ac_gen_row_jpc, PG] .= -P_ac
            jpc1.genAC[ac_gen_row_jpc1, PG] .= -P_ac
        end
    end
    
    # 运行AC潮流计算
    if !isempty(jpc1.busAC)
        jpc1 = PowerFlow.runpf(jpc1, opt)
    end
end

# 先运行交流再运行直流的函数（适用于CONV_MODE为1、2、3的情况）
function run_ac_first(jpc, jpc1, jpc2, opt)
    # 运行AC潮流计算
    if !isempty(jpc1.busAC)
        jpc1 = PowerFlow.runpf(jpc1, opt)
    end
    
    # 处理工作模式为constant δs、Us (CONV_MODE==1)
    converters_delta_us = filter(row -> row[CONV_MODE] == 1, eachrow(jpc.converter))
    if !isempty(converters_delta_us)
        converters_index = findall(row -> row[CONV_MODE] == 1, eachrow(jpc.converter))
        for i in eachindex(converters_delta_us[:, 1])
            conv = converters_delta_us[i]  # 获取第i行作为当前换流器
            gen_row = findfirst(x -> x == Int(conv[CONV_ACBUS]), jpc1.genAC[:, 1])
            P_ac = -jpc1.genAC[gen_row, PG]
            Q_ac = -jpc1.genAC[gen_row, QG]
            if P_ac < 0
                P_dc = -P_ac/conv[CONV_EFF]
            else
                P_dc = -P_ac * conv[CONV_EFF]
            end

            # 更新换流器的直流功率
            jpc.converter[converters_index[i], CONV_P_DC] = P_dc
            jpc.converter[converters_index[i], CONV_Q_AC] = Q_ac
            jpc.converter[converters_index[i], CONV_P_AC] = P_ac

            dc_bus_rows_jpc = findall(x -> x == Int(conv[CONV_DCBUS]), jpc.busDC[:, 1])
            dc_bus_rows_jpc2 = findall(x -> x == Int(conv[CONV_DCBUS]), jpc2.busDC[:, 1])
            jpc.busDC[dc_bus_rows_jpc, PD] .+= P_dc
            jpc2.busDC[dc_bus_rows_jpc2, PD] .+= P_dc

            dc_load_rows_jpc = findall(x -> x == Int(conv[CONV_DCBUS]), jpc.loadDC[:, 2])
            dc_load_rows_jpc2 = findall(x -> x == Int(conv[CONV_DCBUS]), jpc2.loadDC[:, 2])
            if !isempty(dc_load_rows_jpc)
                jpc.loadDC[dc_load_rows_jpc, LOAD_PD] .+= P_dc
                jpc2.loadDC[dc_load_rows_jpc2, LOAD_PD] .+= P_dc
            else
                 # 如果没有直流负荷，则创建一个虚拟负荷
                dc_bus_id = Int(conv[CONV_DCBUS])
                
                # 创建新的虚拟负荷行
                # 假设loadDC的列结构为：[1:负荷ID, 2:母线ID, 3:有功功率, ...]
                new_load_id = isempty(jpc.loadDC) ? 1 : maximum(jpc.loadDC[:, 1]) + 1
                
                # 创建新的负荷行，初始化所有值为0
                new_load_row = zeros(1, 8)
                new_load_row[LOAD_I] = new_load_id  # 负荷ID
                new_load_row[LOAD_CND] = dc_bus_id    # 母线ID
                new_load_row[LOAD_STATUS] = 1  # 工作状态
                new_load_row[LOAD_PD] = P_dc   # 有功功率
                new_load_row[LOADP_PERCENT] = 1.0  # 有功百分比
                
                # 将新的负荷行添加到jpc和jpc2的loadDC中
                jpc.loadDC = vcat(jpc.loadDC, reshape(new_load_row, 1, :))
                jpc2.loadDC = vcat(jpc2.loadDC, reshape(new_load_row, 1, :))
                
                # 如果loadDC是空的，需要特殊处理
                if isempty(dc_load_rows_jpc)
                    dc_load_rows_jpc = [size(jpc.loadDC, 1)]
                    dc_load_rows_jpc2 = [size(jpc2.loadDC, 1)]
                end

            end
        end
    end

    # 处理工作模式为constant Ps、Qs (CONV_MODE==2)
    # 什么都不做、默认模式
    
    # 处理工作模式为constant Ps、Us (CONV_MODE==3)
    converters_ps_us = filter(row -> row[CONV_MODE] == 3, eachrow(jpc.converter))
    if !isempty(converters_ps_us)
        converters_index = findall(row -> row[CONV_MODE] == 3, eachrow(jpc.converter))
        for i in eachindex(converters_ps_us[:, 1])
            conv = converters_ps_us[i]  # 获取第i行作为当前换流器
            gen_row = findfirst(x -> x == Int(conv[CONV_ACBUS]), jpc1.genAC[:, 1])
            P_ac = -jpc1.genAC[gen_row, PG]
            Q_ac = -jpc1.genAC[gen_row, QG]
            if P_ac < 0
                P_dc = -P_ac/conv[CONV_EFF]
            else
                P_dc = -P_ac * conv[CONV_EFF]
            end

            # 更新换流器的直流功率
            jpc.converter[converters_index[i], CONV_P_DC] = P_dc
            jpc.converter[converters_index[i], CONV_Q_AC] = Q_ac
            jpc.converter[converters_index[i], CONV_P_AC] = P_ac

            dc_bus_rows_jpc = findall(x -> x == Int(conv[CONV_DCBUS]), jpc.busDC[:, 1])
            dc_bus_rows_jpc2 = findall(x -> x == Int(conv[CONV_DCBUS]), jpc2.busDC[:, 1])
            jpc.busDC[dc_bus_rows_jpc, PD] .+= P_dc
            jpc2.busDC[dc_bus_rows_jpc2, PD] .+= P_dc

            dc_load_rows_jpc = findall(x -> x == Int(conv[CONV_DCBUS]), jpc.loadDC[:, 2])
            dc_load_rows_jpc2 = findall(x -> x == Int(conv[CONV_DCBUS]), jpc2.loadDC[:, 2])

            if !isempty(dc_load_rows_jpc)
                jpc.loadDC[dc_load_rows_jpc, LOAD_PD] .+= P_dc
                jpc2.loadDC[dc_load_rows_jpc2, LOAD_PD] .+= P_dc
            else
                 # 如果没有直流负荷，则创建一个虚拟负荷
                dc_bus_id = Int(conv[CONV_DCBUS])
                
                # 创建新的虚拟负荷行
                # 假设loadDC的列结构为：[1:负荷ID, 2:母线ID, 3:有功功率, ...]
                new_load_id = isempty(jpc.loadDC) ? 1 : maximum(jpc.loadDC[:, 1]) + 1
                
                # 创建新的负荷行，初始化所有值为0
                new_load_row = zeros(1, 8)
                new_load_row[LOAD_I] = new_load_id  # 负荷ID
                new_load_row[LOAD_CND] = dc_bus_id    # 母线ID
                new_load_row[LOAD_STATUS] = 1  # 工作状态
                new_load_row[LOAD_PD] = P_dc   # 有功功率
                new_load_row[LOADP_PERCENT] = 1.0  # 有功百分比
                
                # 将新的负荷行添加到jpc和jpc2的loadDC中
                jpc.loadDC = vcat(jpc.loadDC, reshape(new_load_row, 1, :))
                jpc2.loadDC = vcat(jpc2.loadDC, reshape(new_load_row, 1, :))
                
                # 如果loadDC是空的，需要特殊处理
                if isempty(dc_load_rows_jpc)
                    dc_load_rows_jpc = [size(jpc.loadDC, 1)]
                    dc_load_rows_jpc2 = [size(jpc2.loadDC, 1)]
                end

            end
        end
    end

    # 运行DC潮流计算
    if !isempty(jpc2.busDC)
        jpc2 = PowerFlow.rundcpf(jpc2, opt)
    end
end
