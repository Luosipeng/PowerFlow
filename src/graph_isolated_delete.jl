"""
初始化电网图，包含母线和支路信息

参数:
- bus::Matrix{Float64}: 母线数据矩阵
- branch::Matrix{Float64}: 支路数据矩阵
- HVCB_data::DataFrame: 高压断路器数据框

返回:
- SimpleGraph: 表示电网拓扑的无向图
"""
function initialize_graph(bus::Matrix{Float64}, 
                        branch::Matrix{Float64}, 
                        HVCB_data::DataFrame)::SimpleGraph
    # 获取索引常量
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = PowerFlow.idx_bus();
    
    (FBUS, TBUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, STATUS, ANGMIN,
    ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF, MU_ST, MU_ANGMIN, MU_ANGMAX, LAMBDA, SW_TIME, RP_TIME, BR_TYPE, BR_AREA) = PowerFlow.idx_brch()
    
    (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
     HVCB_INSERVICE, HVCB_STATUS) = PowerFlow.hvcb_idx()

    # 创建无向图
    g = SimpleGraph(size(bus, 1))
    
    # 添加支路边
    nb = size(branch, 1)
    for i in 1:nb
        if branch[i, STATUS] == 1  # 只添加投运的支路
            add_edge!(g, Int(branch[i, FBUS]), Int(branch[i, TBUS]))
        end
    end
    
     # 添加闭合断路器的边
     for row in eachrow(HVCB_data)
        # 检查断路器状态和运行状态
        is_closed = uppercase(string(row[HVCB_STATUS])) == "CLOSED"  # 全大写比较
        is_inservice = uppercase(string(row[HVCB_INSERVICE])) == "TRUE"  # 全大写比较
    
        if is_closed && is_inservice
            add_edge!(g, Int(row[HVCB_FROM_ELEMENT]), 
                     Int(row[HVCB_TO_ELEMENT]))
        end
    end
    
    return g
end

"""
获取电源节点（发电机和外部电网）

参数:
- bus::Matrix{Float64}: 母线数据矩阵

返回:
- Vector{Int}: 电源节点编号列表
"""
function get_source_buses(bus::Matrix{Float64})::Vector{Int}
    (PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = idx_bus();
    
    # 获取所有发电机节点(PV)和平衡节点(REF)
    source_buses = findall(x -> x in [PV, REF], bus[:, TYPE])
    return Int.(bus[source_buses, BUS_I])
end

"""
从电源节点开始进行广度优先搜索，标记所有可达节点

参数:
- g::SimpleGraph: 电网拓扑图
- source_buses::Vector{Int}: 电源节点列表

返回:
- Set{Int}: 可供电节点集合
"""
function find_energized_buses(g::SimpleGraph, source_buses::Vector{Int})::Set{Int}
    energized = Set{Int}()
    queue = Queue{Int}()
    
    # 将所有电源节点加入队列
    for bus in source_buses
        enqueue!(queue, bus)
        push!(energized, bus)
    end
    
    # 广度优先搜索
    while !isempty(queue)
        current = dequeue!(queue)
        
        # 遍历当前节点的所有邻接节点
        for neighbor in neighbors(g, current)
            if !(neighbor in energized)
                enqueue!(queue, neighbor)
                push!(energized, neighbor)
            end
        end
    end
    
    return energized
end

"""
移除孤岛对应的母线

参数:
- bus::Matrix{Float64}: 母线数据矩阵
- isolated_buses::Set{Int}: 孤岛节点集合

返回:
- Matrix{Float64}: 更新后的母线数据矩阵
"""
function remove_isolated_buses(bus::Matrix{Float64}, 
                             isolated_buses::Set{Int})::Matrix{Float64}
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = idx_bus();
    
    # 保留非孤岛节点
    remaining_rows = findall(x -> !(x in isolated_buses), bus[:, BUS_I])
    return bus[remaining_rows, :]
end

"""
移除孤岛对应的支路

参数:
- branch::Matrix{Float64}: 支路数据矩阵
- isolated_buses::Set{Int}: 孤岛节点集合

返回:
- Matrix{Float64}: 更新后的支路数据矩阵
"""
function remove_isolated_branches(branch::Matrix{Float64}, 
                                isolated_buses::Set{Int})::Matrix{Float64}
    (FBUS, TBUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, 
    BR_STATUS, ANGMIN, ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF,
    MU_ST, MU_ANGMIN, MU_ANGMAX) = idx_brch()

    # 找出不包含孤岛节点的支路
    remaining_rows = findall(row -> 
        !(Int(branch[row, FBUS]) in isolated_buses || 
          Int(branch[row, TBUS]) in isolated_buses), 
        1:size(branch, 1))
    
    return branch[remaining_rows, :]
end

"""
移除孤岛对应的断路器

参数:
- HVCB_data::DataFrame: 母线数据矩阵
- isolated_buses::Set{Int}: 孤岛节点集合

返回:
- DataFrame{Float64}: 更新后的母线数据矩阵
"""
function remove_isolated_HVCB(HVCB_data::DataFrame, 
                            isolated_buses::Set{Int})::DataFrame
    (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
     HVCB_INSERVICE, HVCB_STATUS) = hvcb_idx()
    
    # 找出不包含孤岛节点的断路器
    remaining_rows = findall(row -> 
        !(Int(HVCB_data[row, HVCB_FROM_ELEMENT]) in isolated_buses || 
          Int(HVCB_data[row, HVCB_TO_ELEMENT]) in isolated_buses), 
        1:nrow(HVCB_data))
    
    return HVCB_data[remaining_rows, :]
    
end

function remove_isolated_load(load::Matrix{Float64}, isolated_buses::Set{Int})::Matrix{Float64}
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=idx_ld()
    remaining_rows = findall(row -> !(Int(load[row, LOAD_CND]) in isolated_buses), 1:size(load, 1))
    return load[remaining_rows, :]
end
"""
基于电源可达性的孤岛检测和处理

参数:
- bus::Matrix{Float64}: 母线数据矩阵
- branch::Matrix{Float64}: 支路数据矩阵
- HVCB_data::DataFrame: 高压断路器数据框

返回:
- Tuple{Matrix{Float64}, Matrix{Float64}}: 更新后的母线和支路数据矩阵
"""
function process_islands_by_source(bus::Matrix{Float64}, 
                                 branch::Matrix{Float64}, 
                                 HVCB_data::DataFrame,
                                 load::Matrix{Float64})::Tuple{Matrix{Float64}, Matrix{Float64}, DataFrame, Matrix{Float64}}
                                 
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = PowerFlow.idx_bus();
    # (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
    #  HVCB_INSERVICE, HVCB_STATUS) = hvcb_idx()

    # 初始化图
    g = PowerFlow.initialize_graph(bus, branch, HVCB_data)
    
    # 获取电源节点
    source_buses = PowerFlow.get_source_buses(bus)
    println("电源节点: ", source_buses)
    
    # 获取所有可供电节点
    energized_buses = PowerFlow.find_energized_buses(g, source_buses)
    # println("可供电节点: ", energized_buses)
    
    # 获取孤岛节点（未被供电的节点）
    all_buses = Set(Int.(bus[:, BUS_I]))
    isolated_buses = setdiff(all_buses, energized_buses)
    
    if !isempty(isolated_buses)
        println("检测到孤岛节点: ", isolated_buses)
        
        # 移除孤岛母线
        bus = PowerFlow.remove_isolated_buses(bus, isolated_buses)
        
        # 移除孤岛支路
        branch = PowerFlow.remove_isolated_branches(branch, isolated_buses)

        #移除孤岛断路器
        HVCB_data = PowerFlow.remove_isolated_HVCB(HVCB_data, isolated_buses)

        #移除孤岛负荷
        load = PowerFlow.remove_isolated_load(load, isolated_buses)
        
        println("已移除 $(length(isolated_buses)) 个孤岛节点")
    else
        println("未检测到孤岛")
    end
    
    return bus, branch, HVCB_data,load
end

"""
打印电网统计信息

参数:
- bus::Matrix{Float64}: 母线数据矩阵
- branch::Matrix{Float64}: 支路数据矩阵
- HVCB_data::DataFrame: 高压断路器数据框
"""
function print_network_stats(bus::Matrix{Float64}, 
                           branch::Matrix{Float64}, 
                           HVCB_data::DataFrame)
    println("\n电网统计信息:")
    println("总母线数: ", size(bus, 1))
    println("总支路数: ", size(branch, 1))
    println("断路器数: ", nrow(HVCB_data))
    
    # 获取电源节点信息
    source_buses = get_source_buses(bus)
    println("电源节点数: ", length(source_buses))
    
    # 获取图的连通性信息
    g = initialize_graph(bus, branch, HVCB_data)
    components = connected_components(g)
    println("连通分量数: ", length(components))
    
    if length(components) > 1
        println("各连通分量大小: ", [length(c) for c in components])
    end
end
