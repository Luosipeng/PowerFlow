function extract_islands(mpc)
    # extract_islands - 提取网络中的所有孤岛
    #
    # 用法:
    #   mpc_list = extract_islands(mpc)
    #
    # 返回一个包含每个孤岛的电力系统案例字典数组
    
    # 定义数据矩阵的命名索引
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = idx_bus();
    
    (F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, BR_STATUS, ANGMIN,
     ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF, MU_ST, MU_ANGMIN, MU_ANGMAX, LAMBDA, SW_TIME, RP_TIME, BR_TYPE, BR_AREA) = idx_brch()
    
    (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, PC1,
     PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, 
     RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
      COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN,GEN_AREA) = idx_gen();
    
    # 设置连接矩阵
    nb = size(mpc["bus"], 1)     # 母线数量
    nl = size(mpc["branch"], 1)  # 支路数量
    ng = size(mpc["gen"], 1)     # 发电机数量
    
    if haskey(mpc, "dcline")
        ndc = size(mpc["dcline"], 1)  # 直流线路数量
    else
        ndc = 0
    end

    # 创建外部母线编号到内部索引的映射
    i2e = mpc["bus"][:, BUS_I]
    e2i = Dict{Int, Int}()
    for i in 1:nb
        e2i[Int(i2e[i])] = i
    end
    
    # 找出所有岛屿
    groups, isolated = PowerFlow.find_islands(mpc)
    
    # 提取每个岛屿
    mpc_list = []
    for i in eachindex(groups)
        # 获取岛屿i中的外部母线编号
        b_external = groups[i]
        
        # 将外部母线编号转换为内部索引
        b_internal = []
        for bus_id in b_external
            if haskey(e2i, bus_id)
                push!(b_internal, e2i[bus_id])
            else
                @warn "母线编号 $bus_id 不在系统中"
            end
        end
        
        # 找出两端都在岛屿i中的支路
        ibr = []
        for j in 1:nl
            f_bus = Int(mpc["branch"][j, F_BUS])
            t_bus = Int(mpc["branch"][j, T_BUS])
            if (f_bus in b_external) && (t_bus in b_external)
                push!(ibr, j)
            end
        end
        
        # 找出连接到岛屿i中母线的发电机
        ig = []
        for j in 1:ng
            gen_bus = Int(mpc["gen"][j, GEN_BUS])
            if gen_bus in b_external
                push!(ig, j)
            end
        end
        
        # 找出两端都在岛屿i中的直流线路
        idc = []
        if ndc > 0
            c = idx_dcline()
            for j in 1:ndc
                f_bus = Int(mpc["dcline"][j, c.F_BUS])
                t_bus = Int(mpc["dcline"][j, c.T_BUS])
                if (f_bus in b_external) && (t_bus in b_external)
                    push!(idc, j)
                end
            end
        end
        
        # 创建这个岛屿的mpc副本
        mpck = Dict{String, Any}()
        for (key, val) in mpc
            if !(key in ["bus", "branch", "gen", "gencost", "dcline", "dclinecost", "bus_name", "gentype", "genfuel"])
                mpck[key] = deepcopy(val)
            end
        end
        
        mpck["bus"] = mpc["bus"][b_internal, :]
        mpck["branch"] = mpc["branch"][ibr, :]
        mpck["gen"] = mpc["gen"][ig, :]
        
        if haskey(mpc, "gencost")
            if size(mpc["gencost"], 1) == 2*ng
                mpck["gencost"] = mpc["gencost"][vcat(ig, ng .+ ig), :]
            elseif size(mpc["gencost"], 1) == ng
                mpck["gencost"] = mpc["gencost"][ig, :]
            else
                @warn "gencost矩阵行数不正确。期望 $ng 或 $(2*ng) 行，实际有 $(size(mpc["gencost"], 1)) 行。"
                # 可以选择不设置gencost，或者使用默认值
                # mpck["gencost"] = []  # 设置为空数组
                # 或者尝试使用原始gencost（可能会导致后续问题）
                mpck["gencost"] = mpc["gencost"]
            end
        end
        
        if haskey(mpc, "gentype")
            mpck["gentype"] = mpc["gentype"][ig]
        end
        
        if haskey(mpc, "genfuel")
            mpck["genfuel"] = mpc["genfuel"][ig]
        end
        
        if haskey(mpc, "bus_name")
            mpck["bus_name"] = mpc["bus_name"][b_internal]
        end
        
        if ndc > 0 && !isempty(idc)
            mpck["dcline"] = mpc["dcline"][idc, :]
            if haskey(mpc, "dclinecost")
                mpck["dclinecost"] = mpc["dclinecost"][idc, :]
            end
        end
        
        push!(mpc_list, mpck)
    end
    
    # 处理孤立的母线
    isolated_internal = []
    for bus_id in isolated
        if haskey(e2i, bus_id)
            push!(isolated_internal, e2i[bus_id])
        end
    end
    
    return mpc_list, isolated
end
