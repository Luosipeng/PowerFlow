

"""
将潮流计算结果格式化为MATPOWER风格的报告并保存为文本文件
"""
function generate_matpower_report(mpc::Dict{String, Any},area, execution_time, isolated, output_file::String="powerflow_report.txt")
    # 打开文件用于写入
    open(output_file, "w") do f
        # 写入报告头部
        write(f, "JUPOWER Version 0.01, $(Dates.format(now(), "dd-u-yyyy"))\n")
        write(f, "Power Flow -- AC-polar-power formulation\n\n")
        
        # 写入收敛信息
        write(f, "Newton's method converged in $(mpc["iterations"]) iterations.\n")
        if get(mpc, "success", false)
            write(f, "PF successful\n\n")
        else
            write(f, "PF NOT successful\n\n")
        end
        
        # 假设计算时间
        write(f, "Converged in $(execution_time) seconds\n")
        
        # 系统摘要
        write_system_summary(f, mpc, area, isolated)
        
        # 母线数据
        write_bus_data(f, mpc, isolated)
        
        # 支路数据
        write_branch_data(f, mpc)
    end
    
    println("报告已保存至 $output_file")
end

"""
写入系统摘要部分
"""
function write_system_summary(f::IOStream, mpc::Dict{String, Any}, area, isolated)
    # 提取必要的数据
    baseMVA = mpc["baseMVA"]
    
    # 计算基本统计数据
    if haskey(mpc, "bus")
        n_buses = size(mpc["bus"], 1)
    else
        # 从其他数据推断母线数量
        bus_ids = Set()
        if haskey(mpc, "branch")
            for i in 1:size(mpc["branch"], 1)
                push!(bus_ids, mpc["branch"][i, 1])
                push!(bus_ids, mpc["branch"][i, 2])
            end
        end
        if haskey(mpc, "gen")
            for i in 1:size(mpc["gen"], 1)
                push!(bus_ids, mpc["gen"][i, 1])
            end
        end
        if haskey(mpc, "load")
            for i in 1:size(mpc["load"], 1)
                push!(bus_ids, mpc["load"][i, 1])
            end
        end
        n_buses = length(bus_ids)
    end
    n_isolated = length(isolated)
    n_buses = n_buses + n_isolated
    # 获取发电机数量
    n_gens = haskey(mpc, "gen") ? size(mpc["gen"], 1) : 0
    
    # 获取负荷数量
    n_loads = haskey(mpc, "load") ? size(mpc["load"], 1) : 0
    
    # 获取支路数量
    n_branches = haskey(mpc, "branch") ? size(mpc["branch"], 1) : 0
    
    # 计算变压器数量 (假设branch矩阵中有tap列)
    n_transformers = 0
    if haskey(mpc, "branch") && size(mpc["branch"], 2) >= 9
        for i in 1:size(mpc["branch"], 1)
            if abs(mpc["branch"][i, 9] ) > 1e-6
                n_transformers += 1
            end
        end
    end
    
    # 计算发电总量和负荷总量
    total_gen_p = 0.0
    total_gen_q = 0.0
    if haskey(mpc, "gen")
        # 假设gen矩阵的第2列是有功功率，第3列是无功功率
        total_gen_p = sum(mpc["gen"][:, 2]) 
        total_gen_q = sum(mpc["gen"][:, 3]) 
    end
    
    total_load_p = 0.0
    total_load_q = 0.0
    if haskey(mpc, "bus")
        # 假设load矩阵的第3列是有功负荷，第4列是无功负荷
        if size(mpc["bus"], 2) >= 4
            total_load_p = sum(mpc["bus"][:, 3]) 
            total_load_q = sum(mpc["bus"][:, 4]) 
        end
    end
    
    # 计算损耗
    total_p_loss = total_gen_p - total_load_p
    total_q_loss = 0.0
    charging_q = 0.0
    for i in 1:size(mpc["branch"], 1)
        branch_id = i
        from_bus = Int(mpc["branch"][i, 1])
        to_bus = Int(mpc["branch"][i, 2])
            
        # 获取线路参数
        r = mpc["branch"][i, 3] 
        x = mpc["branch"][i, 4]
        b = mpc["branch"][i, 5]  # 线路半充电电纳
            
        # 获取实际的母线电压值和相角
        v_from = 1.0  # 默认值，如果找不到实际电压
        v_to = 1.0    # 默认值，如果找不到实际电压
        ang_from = 0.0
        ang_to = 0.0
            
        # 从母线数据中查找实际电压值和相角
        for j in 1:size(mpc["bus"], 1)
            if Int(mpc["bus"][j, 1]) == from_bus
                v_from = mpc["bus"][j, 8]  # 使用实际电压幅值
                ang_from = mpc["bus"][j, 9] * pi/180  # 转换为弧度
            elseif Int(mpc["bus"][j, 1]) == to_bus
                v_to = mpc["bus"][j, 8]    # 使用实际电压幅值
                ang_to = mpc["bus"][j, 9] * pi/180  # 转换为弧度
            end
        end
            
        # 相角差
        angle_diff = ang_from - ang_to
            
        # 计算线路导纳
        y = 1 / complex(r, x)
        y_abs = abs(y)
            
        # 直接计算线路电流幅值平方
        i_mag_squared = (v_from^2 + v_to^2 - 2*v_from*v_to*cos(angle_diff)) * y_abs^2
            
        # 计算无功损耗 - 使用电抗和电流平方
        q_loss = x * i_mag_squared * baseMVA

        charging_from = 0.5 * b * v_from^2 * baseMVA
        charging_to = 0.5 * b * v_to^2 * baseMVA
        charging_q += charging_from + charging_to
        total_q_loss += q_loss
        end
    
    # 计算发电机容量
    total_gen_pmax = 0.0
    total_gen_qmin = 0.0
    total_gen_qmax = 0.0
    if haskey(mpc, "gen") && size(mpc["gen"], 2) >= 6
        total_gen_pmax = sum(mpc["gen"][:, 9]) 
        total_gen_qmin = sum(mpc["gen"][:, 5])
        total_gen_qmax = sum(mpc["gen"][:, 4])
    end
    
    # 写入系统摘要
    write(f, "================================================================================\n")
    write(f, "|     System Summary                                                           |\n")
    write(f, "================================================================================\n\n")
    
    @printf(f, "How many?                How much?              P (MW)            Q (MVAr)\n")
    @printf(f, "---------------------    -------------------  -------------  -----------------\n")
    @printf(f, "Buses            %3d     Total Gen Capacity    %7.1f       %7.1f to %7.1f\n", 
            n_buses, total_gen_pmax, total_gen_qmin, total_gen_qmax)
    @printf(f, "Generators       %3d     On-line Capacity      %7.1f       %7.1f to %7.1f\n", 
            n_gens, total_gen_pmax, total_gen_qmin, total_gen_qmax)
    @printf(f, "Committed Gens   %3d     Generation (actual)   %7.1f             %7.1f\n", 
            n_gens, total_gen_p, total_gen_q)
    @printf(f, "Loads            %3d     Load                  %7.1f            %7.1f\n", 
            n_loads, total_load_p, total_load_q)
    @printf(f, "  Fixed          %3d       Fixed               %7.1f            %7.1f\n", 
            n_loads, total_load_p, total_load_q)
    @printf(f, "  Dispatchable    %2d       Dispatchable          %4.1f of %4.1f      %5.1f\n", 
            0, 0.0, 0.0, 0.0)
    @printf(f, "Shunts           %3d     Shunt (inj)             %5.1f              %5.1f\n", 
            0, 0.0, 0.0)  # 假设没有分路元件
    @printf(f, "Branches         %3d     Losses (I^2 * Z)       %6.2f            %6.2f\n", 
            n_branches, total_p_loss, total_q_loss)  # 无功损耗需要计算
    @printf(f, "Transformers     %3d     Branch Charging (inj)     -             %6.1f\n", 
            n_transformers, charging_q)  # 需要计算实际值
    @printf(f, "Inter-ties        %2d     Total Inter-tie Flow     %4.1f               %4.1f\n", 
            0, 0.0, 0.0)
    @printf(f, "Areas             %2d\n\n", area)
    
    # 电压和相角的最大最小值
    # 这部分需要从bus数据中提取，如果没有完整的bus数据，可以省略或使用估计值
    if haskey(mpc, "bus") && size(mpc["bus"], 2) >= 3
        min_vm = Inf
        max_vm = -Inf
        min_vm_bus = 0
        max_vm_bus = 0
        min_va = Inf
        max_va = -Inf
        min_va_bus = 0
        max_va_bus = 0
        
        for i in 1:size(mpc["bus"], 1)
            vm = mpc["bus"][i, 8]
            va = mpc["bus"][i, 9]
            
            if vm < min_vm
                min_vm = vm
                min_vm_bus = Int(mpc["bus"][i, 1])
            end
            if vm > max_vm
                max_vm = vm
                max_vm_bus = Int(mpc["bus"][i, 1])
            end
            
            if va < min_va
                min_va = va
                min_va_bus = Int(mpc["bus"][i, 1])
            end
            if va > max_va
                max_va = va
                max_va_bus = Int(mpc["bus"][i, 1])
            end
        end
        
        @printf(f, "                          Minimum                      Maximum\n")
        @printf(f, "                 -------------------------  --------------------------------\n")
        @printf(f, "Voltage Magnitude   %5.3f p.u. @ bus %3d         %5.3f p.u. @ bus %3d  \n", 
                min_vm, min_vm_bus, max_vm, max_vm_bus)
        @printf(f, "Voltage Angle      %6.2f deg   @ bus %3d        %6.2f deg   @ bus %3d  \n", 
                min_va, min_va_bus, max_va, max_va_bus)
    end
    
    # 线路损耗信息
    # 如果有详细的支路损耗数据，可以添加这部分
    if haskey(mpc, "branch")
        # 处理支路损耗数据
        max_p_loss= -Inf
        max_q_loss = -Inf
        max_p_line = 0
        max_q_line = 0
        p_loss = mpc["branch"][:, 15] + mpc["branch"][:, 17]
        q_loss = mpc["branch"][:, 16] + mpc["branch"][:, 18]
        for i in 1:size(mpc["branch"], 1)
            ploss= p_loss[i]
            qloss= q_loss[i]
            if ploss > max_p_loss
                max_p_loss = ploss
                max_p_line = i
            end
            if qloss > max_q_loss
                max_q_loss = qloss
                max_q_line = i
            end

        end
        # 使用估计值或省略
        @printf(f, "P Losses (I^2*R)             -                  %5.2f MW    @ line %s\n", 
        max_p_loss, string(Int(mpc["branch"][max_p_line, 1]), "-", Int(mpc["branch"][max_p_line, 2])))
        @printf(f, "Q Losses (I^2*X)             -                 %5.2f MVAr  @ line %s\n", 
        max_q_loss, string(Int(mpc["branch"][max_q_line, 1]), "-", Int(mpc["branch"][max_q_line, 2])))

    else
        # 使用估计值或省略
        @printf(f, "P Losses (I^2*R)             -                  %5.2f MW    @ line %s\n", 
                0.0, "X-X")
        @printf(f, "Q Losses (I^2*X)             -                 %5.2f MVAr  @ line %s\n", 
                0.0, "X-X")
    end
    
    write(f, "\n")
end

"""
写入母线数据部分
"""
function write_bus_data(f::IOStream, mpc::Dict{String, Any}, isolated)
    baseMVA = mpc["baseMVA"]
    
    write(f, "================================================================================\n")
    write(f, "|     Bus Data                                                                 |\n")
    write(f, "================================================================================\n")
    write(f, " Bus      Voltage          Generation             Load        \n")
    write(f, "  #   Mag(pu) Ang(deg)   P (MW)   Q (MVAr)   P (MW)   Q (MVAr)\n")
    write(f, "----- ------- --------  --------  --------  --------  --------\n")
    
    # 创建母线数据表
    # 需要从mpc中提取bus、gen和load数据
    
    # 假设我们有完整的bus数据
    if haskey(mpc, "bus") && size(mpc["bus"], 2) >= 3
        # 创建发电机和负荷查找表
        gen_lookup = Dict{Int, Tuple{Float64, Float64}}()
        if haskey(mpc, "gen")
            for i in 1:size(mpc["gen"], 1)
                bus_id = Int(mpc["gen"][i, 1])
                pg = mpc["gen"][i, 2] 
                qg = mpc["gen"][i, 3] 
                gen_lookup[bus_id] = (pg, qg)
            end
        end
        
        load_lookup = Dict{Int, Tuple{Float64, Float64}}()
        if haskey(mpc, "bus")
            for i in 1:size(mpc["bus"], 1)
                bus_id = Int(mpc["bus"][i, 1])
                pd = mpc["bus"][i, 3] 
                qd = mpc["bus"][i, 4] 
                load_lookup[bus_id] = (pd, qd)
            end
        end
        
        #添加孤岛
        for i in eachindex(isolated)
            isolated_bus = zeros(1, 13)
            isolated_bus[1] = isolated[i]
            isolated_bus[2] = 1.0
            isolated_bus[3] = 0.0
            isolated_bus[4] = 0.0
            isolated_bus[5] = 0.0
            isolated_bus[6] = 0.0
            isolated_bus[7] = 1.0
            isolated_bus[8] = 0.0
            isolated_bus[9] = 0.0
            isolated_bus[10] = 0.0
            isolated_bus[11] = 1.0
            isolated_bus[12] = 1.1
            isolated_bus[13] = 0.9
            mpc["bus"] = vcat(mpc["bus"], isolated_bus)
        end
        
        # 根据母线编号对mpc["bus"]进行排序
        bus_ids = mpc["bus"][:, 1]
        sorted_indices = sortperm(bus_ids)
        mpc["bus"] = mpc["bus"][sorted_indices, :]

        # 总计
        total_pg = 0.0
        total_qg = 0.0
        total_pd = 0.0
        total_qd = 0.0
        
        # 遍历所有母线
        for i in 1:size(mpc["bus"], 1)
            bus_id = Int(mpc["bus"][i, 1])
            vm = mpc["bus"][i, 8]
            va = mpc["bus"][i, 9]
            
            # 获取发电数据
            pg_str = "-"
            qg_str = "-"
            if haskey(gen_lookup, bus_id)
                pg, qg = gen_lookup[bus_id]
                pg_str = @sprintf("%.2f", pg)
                qg_str = @sprintf("%.2f", qg)
                total_pg += pg
                total_qg += qg
            end
            
            # 获取负荷数据
            pd = 0.0
            qd = 0.0
            if haskey(load_lookup, bus_id)
                pd, qd = load_lookup[bus_id]
                total_pd += pd
                total_qd += qd
            end
            
            # 打印母线数据
            @printf(f, "%5d  %5.3f   %6.3f   %8s   %8s   %7.2f   %7.2f \n", 
                    bus_id, vm, va, pg_str, qg_str, pd, qd)
        end
        
        # 打印总计
        @printf(f, "                        --------  --------  --------  --------\n")
        @printf(f, "               Total:   %7.2f   %7.2f   %7.2f   %7.2f\n", 
                total_pg, total_qg, total_pd, total_qd)
    else
        # 如果没有完整的bus数据，尝试从其他数据构建
        bus_ids = Set{Int}()
        
        # 从gen、load和branch数据中收集所有母线ID
        if haskey(mpc, "gen")
            for i in 1:size(mpc["gen"], 1)
                push!(bus_ids, Int(mpc["gen"][i, 1]))
            end
        end
        
        if haskey(mpc, "load")
            for i in 1:size(mpc["load"], 1)
                push!(bus_ids, Int(mpc["load"][i, 1]))
            end
        end
        
        if haskey(mpc, "branch")
            for i in 1:size(mpc["branch"], 1)
                push!(bus_ids, Int(mpc["branch"][i, 1]))
                push!(bus_ids, Int(mpc["branch"][i, 2]))
            end
        end
        
        # 创建发电机和负荷查找表
        gen_lookup = Dict{Int, Tuple{Float64, Float64}}()
        if haskey(mpc, "gen")
            for i in 1:size(mpc["gen"], 1)
                bus_id = Int(mpc["gen"][i, 1])
                pg = mpc["gen"][i, 2] * baseMVA
                qg = mpc["gen"][i, 3] * baseMVA
                gen_lookup[bus_id] = (pg, qg)
            end
        end
        
        load_lookup = Dict{Int, Tuple{Float64, Float64}}()
        if haskey(mpc, "load")
            for i in 1:size(mpc["load"], 1)
                bus_id = Int(mpc["load"][i, 1])
                pd = mpc["load"][i, 3] * baseMVA
                qd = mpc["load"][i, 4] * baseMVA
                load_lookup[bus_id] = (pd, qd)
            end
        end
        
        # 总计
        total_pg = 0.0
        total_qg = 0.0
        total_pd = 0.0
        total_qd = 0.0
        
        # 遍历所有收集到的母线ID
        for bus_id in sort(collect(bus_ids))
            # 假设电压数据
            vm = 1.0  # 默认值
            va = 0.0  # 默认值
            
            # 获取发电数据
            pg_str = "-"
            qg_str = "-"
            if haskey(gen_lookup, bus_id)
                pg, qg = gen_lookup[bus_id]
                pg_str = @sprintf("%.2f", pg)
                qg_str = @sprintf("%.2f", qg)
                total_pg += pg
                total_qg += qg
            end
            
            # 获取负荷数据
            pd = 0.0
            qd = 0.0
            if haskey(load_lookup, bus_id)
                pd, qd = load_lookup[bus_id]
                total_pd += pd
                total_qd += qd
            end
            
            # 打印母线数据
            @printf(f, "%5d  %5.3f   %6.3f   %8s   %8s   %7.2f   %7.2f \n", 
                    bus_id, vm, va, pg_str, qg_str, pd, qd)
        end
        
        # 打印总计
        @printf(f, "                        --------  --------  --------  --------\n")
        @printf(f, "               Total:   %7.2f   %7.2f   %7.2f   %7.2f\n", 
                total_pg, total_qg, total_pd, total_qd)
    end
    
    write(f, "\n")
end

"""
写入支路数据部分
"""
function write_branch_data(f::IOStream, mpc::Dict{String, Any})
    baseMVA = mpc["baseMVA"]
    
    write(f, "================================================================================\n")
    write(f, "|     Branch Data                                                              |\n")
    write(f, "================================================================================\n")
    write(f, "Brnch   From   To    From Bus Injection   To Bus Injection     Loss (I^2 * Z)  \n")
    write(f, "  #     Bus    Bus    P (MW)   Q (MVAr)   P (MW)   Q (MVAr)   P (MW)   Q (MVAr)\n")
    write(f, "-----  -----  -----  --------  --------  --------  --------  --------  --------\n")
    
    # 检查是否有支路数据
    if !haskey(mpc, "branch") || size(mpc["branch"], 1) == 0
        @printf(f, "No branch data available.\n")
        return
    end
    
    # 检查是否有支路功率流数据
    has_flow_data = haskey(mpc, "branch_flows") || (size(mpc["branch"], 2) >= 14)
    
    total_p_loss = 0.0
    total_q_loss = 0.0
    
    if has_flow_data
        # 假设branch矩阵包含功率流数据
        # 通常MATPOWER格式中，branch矩阵的列14-17是功率流数据
        # [Pf, Qf, Pt, Qt] 分别表示从母线注入、到母线注入的有功和无功功率
        
        for i in 1:size(mpc["branch"], 1)
            branch_id = i
            from_bus = Int(mpc["branch"][i, 1])
            to_bus = Int(mpc["branch"][i, 2])
            
            # 获取功率流数据
            if haskey(mpc, "branch_flows")
                pf = mpc["branch_flows"][i, 1] 
                qf = mpc["branch_flows"][i, 2] 
                pt = mpc["branch_flows"][i, 3] 
                qt = mpc["branch_flows"][i, 4] 
                
                # 获取线路参数
                r = mpc["branch"][i, 3]  # 电阻
                x = mpc["branch"][i, 4]  # 电抗
                b = mpc["branch"][i, 5]  # 电纳(半线充电)
                
                # 获取母线电压值
                v_from = 1.0
                v_to = 1.0
                ang_from = 0.0
                ang_to = 0.0
                
                for j in 1:size(mpc["bus"], 1)
                    if Int(mpc["bus"][j, 1]) == from_bus
                        v_from = mpc["bus"][j, 8]
                        ang_from = mpc["bus"][j, 9] * pi/180
                    elseif Int(mpc["bus"][j, 1]) == to_bus
                        v_to = mpc["bus"][j, 8]
                        ang_to = mpc["bus"][j, 9] * pi/180
                    end
                end
                
                # 计算线路电流
                y = 1 / complex(r, x)
                theta = angle(y)
                
                # 相角差
                angle_diff = ang_from - ang_to
                
                # 计算线路电流幅值
                i_mag_squared = (v_from^2 + v_to^2 - 2*v_from*v_to*cos(angle_diff)) * abs(y)^2
                
                # 计算有功和无功损耗
                p_loss = r * i_mag_squared 
                q_loss = x * i_mag_squared 
            else
                pf = mpc["branch"][i, 15] 
                qf = mpc["branch"][i, 16] 
                pt = mpc["branch"][i, 17] 
                qt = mpc["branch"][i, 18] 
                
                # 如果没有详细数据，可以用近似值进行有功损耗计算
                p_loss = pf + pt
                
                # 获取线路参数
                r = mpc["branch"][i, 3] 
                x = mpc["branch"][i, 4]
                b = mpc["branch"][i, 5]  # 线路半充电电纳
                
                # 获取实际的母线电压值和相角
                v_from = 1.0  # 默认值，如果找不到实际电压
                v_to = 1.0    # 默认值，如果找不到实际电压
                ang_from = 0.0
                ang_to = 0.0
                
                # 从母线数据中查找实际电压值和相角
                for j in 1:size(mpc["bus"], 1)
                    if Int(mpc["bus"][j, 1]) == from_bus
                        v_from = mpc["bus"][j, 8]  # 使用实际电压幅值
                        ang_from = mpc["bus"][j, 9] * pi/180  # 转换为弧度
                    elseif Int(mpc["bus"][j, 1]) == to_bus
                        v_to = mpc["bus"][j, 8]    # 使用实际电压幅值
                        ang_to = mpc["bus"][j, 9] * pi/180  # 转换为弧度
                    end
                end
                
                # 相角差
                angle_diff = ang_from - ang_to
                
                # 计算线路导纳
                y = 1 / complex(r, x)
                y_abs = abs(y)
                
                # 直接计算线路电流幅值平方
                i_mag_squared = (v_from^2 + v_to^2 - 2*v_from*v_to*cos(angle_diff)) * y_abs^2
                
                # 计算无功损耗 - 使用电抗和电流平方
                q_loss = x * i_mag_squared * baseMVA
            end
            
            
            total_p_loss += p_loss
            total_q_loss += q_loss
            
            # 打印支路数据
            @printf(f, "%5d  %5d  %5d  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f\n", 
                    branch_id, from_bus, to_bus, pf, qf, pt, qt, p_loss, q_loss)
        end
    else
        # 如果没有功率流数据，只打印支路拓扑信息
        for i in 1:size(mpc["branch"], 1)
            branch_id = i
            from_bus = Int(mpc["branch"][i, 1])
            to_bus = Int(mpc["branch"][i, 2])
            
            # 打印支路数据（无功率流信息）
            @printf(f, "%5d  %5d  %5d  %8s  %8s  %8s  %8s  %8s  %8s\n", 
                    branch_id, from_bus, to_bus, "-", "-", "-", "-", "-", "-")
        end
    end
    
    # 打印总计
    @printf(f, "                                                             --------  --------\n")
    @printf(f, "                                                    Total:   %8.2f  %8.2f\n", 
            total_p_loss, total_q_loss)
    
    write(f, "\n")
end

"""
从您的数据结构中提取母线数据
"""
function extract_bus_data(mpc::Dict{String, Any})
    # 如果已经有bus数据，直接返回
    if haskey(mpc, "bus")
        return mpc["bus"]
    end
    
    # 否则，尝试从gen、load和branch数据构建基本的bus数据
    bus_ids = Set{Int}()
    
    # 从gen、load和branch数据中收集所有母线ID
    if haskey(mpc, "gen")
        for i in 1:size(mpc["gen"], 1)
            push!(bus_ids, Int(mpc["gen"][i, 1]))
        end
    end
    
    if haskey(mpc, "load")
        for i in 1:size(mpc["load"], 1)
            push!(bus_ids, Int(mpc["load"][i, 1]))
        end
    end
    
    if haskey(mpc, "branch")
        for i in 1:size(mpc["branch"], 1)
            push!(bus_ids, Int(mpc["branch"][i, 1]))
            push!(bus_ids, Int(mpc["branch"][i, 2]))
        end
    end
    
    # 创建基本的bus数据矩阵
    # 列：[bus_id, Vm, Va]
    bus_data = zeros(length(bus_ids), 3)
    
    for (i, bus_id) in enumerate(sort(collect(bus_ids)))
        bus_data[i, 1] = bus_id
        bus_data[i, 2] = 1.0  # 默认电压幅值
        bus_data[i, 3] = 0.0  # 默认相角
    end
    
    return bus_data
end

"""
主函数：生成MATPOWER风格的报告
"""
# function generate_matpower_style_report(mpc::Dict{String, Any}, output_file::String="powerflow_report.txt")
#     # 确保有基本的bus数据
#     if !haskey(mpc, "bus")
#         mpc["bus"] = extract_bus_data(mpc)
#     end
    
#     # 生成报告
#     generate_matpower_report(mpc, output_file)
# end
