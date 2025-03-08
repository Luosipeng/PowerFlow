
"""
处理CB共同连接点，带负荷节点修改为CB的公共交点
输入:
- branch: 支路矩阵
- bus: 节点矩阵
- HVCB_data: CB数据
- FBUS, TBUS: 支路起始和终止节点索引
- BUS_I: 节点编号索引
- HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT: CB的起始和终止元件索引
- HVCB_STATUS: CB状态索引
- HVCB_ID: CB编号索引

返回:
- branch: 更新后的支路矩阵
- bus: 更新后的节点矩阵
- HVCB_data: 更新后的CB数据
"""
function process_load_cb_connections(branch::Matrix{Float64},
                                    bus::Matrix{Float64}, 
                                    gen::Matrix{Float64},
                                    load::Matrix{Float64},
                                    HVCB_data::DataFrame,
                                    PD::Int,
                                    QD::Int,
                                    FBUS::Int, 
                                    TBUS::Int, 
                                    BUS_I::Int,
                                    TYPE::Int,
                                    GEN_BUS::Int,
                                    LOAD_CND::Int,
                                    HVCB_FROM_ELEMENT::Int,
                                    HVCB_TO_ELEMENT::Int,
                                    HVCB_STATUS::Int,
                                    HVCB_ID::Int)
    nc = size(HVCB_data, 1)  # CB个数
    ng= size(gen, 1)  # 发电机数据数量
    nb = size(branch, 1)  # 节点数量
    nd= size(load, 1)  # 负荷数据数量

    # 收集所有元件连接点
    F_element = []
    T_element = []
    for i in 1:nc
        F_element = vcat(F_element, HVCB_data[i, HVCB_FROM_ELEMENT])
        T_element = vcat(T_element, HVCB_data[i, HVCB_TO_ELEMENT])
    end

    #收集所有branch连接点
    F_branch = branch[:, FBUS]
    T_branch = branch[:, TBUS]
    total_connect_branch=vcat(F_branch,T_branch)
    total_connect_branch=unique(total_connect_branch)
    # 找到多个CB共同连接的点
    total_element = vcat(F_element, T_element)
    repeated_elements = unique(filter(x -> count(x .== total_element) > 1, total_element))
    length_repeated_element = length(repeated_elements)

    # 初始化数据结构
    delete_bus_zero = Int[]
    delete_HVCB_zero = String[]
    dict_CB_BUS = Dict()

    # 处理每个重复点
    for i in 1:length_repeated_element
        for j in 1:nc
            # 处理FROM端重复点
            if (repeated_elements[i] == HVCB_data[j,HVCB_FROM_ELEMENT] && 
                HVCB_data[j,HVCB_STATUS] == "Closed")
                other_elements = Set()
                for k in 1:nc
                    if k != j  # 排除自身
                        push!(other_elements, HVCB_data[k, HVCB_TO_ELEMENT])
                        push!(other_elements, HVCB_data[k, HVCB_FROM_ELEMENT])
                    end
                end
                if isempty(intersect(total_connect_branch,HVCB_data[j,HVCB_TO_ELEMENT] )) && 
                    isempty(intersect(other_elements, HVCB_data[j,HVCB_TO_ELEMENT]))
                    dict_CB_BUS[HVCB_data[j,HVCB_TO_ELEMENT]] = HVCB_data[j,HVCB_FROM_ELEMENT]
                    push!(delete_bus_zero, HVCB_data[j,HVCB_TO_ELEMENT])
                    push!(delete_HVCB_zero, HVCB_data[j,HVCB_ID])
                end
            end

            # 处理TO端重复点
            if (repeated_elements[i] == HVCB_data[j,HVCB_TO_ELEMENT] && 
                HVCB_data[j,HVCB_STATUS] == "Closed")
                other_elements = Set()
                for k in 1:nc
                    if k != j  # 排除自身
                        push!(other_elements, HVCB_data[k, HVCB_TO_ELEMENT])
                        push!(other_elements, HVCB_data[k, HVCB_FROM_ELEMENT])
                    end
                end
                if isempty(intersect(total_connect_branch,HVCB_data[j,HVCB_FROM_ELEMENT] )) && 
                    isempty(intersect(other_elements, HVCB_data[j,HVCB_FROM_ELEMENT]))
                    dict_CB_BUS[HVCB_data[j,HVCB_FROM_ELEMENT]] = HVCB_data[j,HVCB_TO_ELEMENT]
                    push!(delete_bus_zero, HVCB_data[j,HVCB_FROM_ELEMENT])
                    push!(delete_HVCB_zero, HVCB_data[j,HVCB_ID])
                end
            end
        end
    end

    # 更新发电机节点连接关系
    for i in 1:ng
        if haskey(dict_CB_BUS, gen[i,GEN_BUS])
            gen_index = dict_CB_BUS[gen[i,GEN_BUS]]
            bus[findall(bus[:,BUS_I].==gen_index),TYPE] = bus[findall(bus[:,BUS_I].==gen[i,GEN_BUS]),TYPE]
            gen[i,GEN_BUS] = gen_index
        end
    end
    #更新负荷节点连接关系
    for i in 1:nd
        if haskey(dict_CB_BUS, load[i,LOAD_CND])
            other_load=findall(load[:,LOAD_CND].==dict_CB_BUS[load[i,LOAD_CND]])
            if isempty(other_load)
                load[i,LOAD_CND] = dict_CB_BUS[load[i,LOAD_CND]]
            else
                load[other_load,LOAD_PD] += load[i,LOAD_PD]
                load[other_load,LOAD_QD] += load[i,LOAD_QD]
                delete!(load,i)
            end
            
        end
    end

    # 删除冗余节点
    if !isempty(delete_bus_zero)
        delete_bus_zero_set = unique(delete_bus_zero)
        
        # 在删除节点之前，将功率相加
        for bus_to_delete in delete_bus_zero_set
            # 找到这个节点对应到哪个节点（在dict_CB_CB中查找）
            if haskey(dict_CB_BUS, bus_to_delete)
                target_bus = dict_CB_BUS[bus_to_delete]
                
                # 找到要删除的节点和目标节点在bus矩阵中的索引
                delete_idx = findfirst(x -> x == bus_to_delete, bus[:, BUS_I])
                target_idx = findfirst(x -> x == target_bus, bus[:, BUS_I])
                
                if !isnothing(delete_idx) && !isnothing(target_idx)
                    # 将有功功率和无功功率加到目标节点上
                    bus[target_idx, PD] += bus[delete_idx, PD]
                    bus[target_idx, QD] += bus[delete_idx, QD]
                end
            end
        end
        
        # 删除节点
        bus = bus[findall(x -> !(x in delete_bus_zero_set), bus[:, BUS_I]), :]
    end

    # 删除冗余CB
    if !isempty(delete_HVCB_zero)
        delete_HVCB_zero_set = unique(delete_HVCB_zero)
        HVCB_data = HVCB_data[findall(x -> !(x in delete_HVCB_zero_set), HVCB_data[:, HVCB_ID]), :]
    end

    return bus, HVCB_data, load
end

"""
处理CB共同连接点，将branch与CB连接的点修改为CB的公共交点
输入:
- branch: 支路矩阵
- bus: 节点矩阵
- HVCB_data: CB数据
- FBUS, TBUS: 支路起始和终止节点索引
- BUS_I: 节点编号索引
- HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT: CB的起始和终止元件索引
- HVCB_STATUS: CB状态索引
- HVCB_ID: CB编号索引

返回:
- branch: 更新后的支路矩阵
- bus: 更新后的节点矩阵
- HVCB_data: 更新后的CB数据
"""
function process_common_cb_connections!(branch::Matrix{Float64}, 
                                     bus::Matrix{Float64}, 
                                     gen::Matrix{Float64},
                                     HVCB_data::DataFrame,
                                     FBUS::Int, 
                                     TBUS::Int, 
                                     BUS_I::Int,
                                     TYPE::Int,
                                     GEN_BUS::Int,
                                     HVCB_FROM_ELEMENT::Int,
                                     HVCB_TO_ELEMENT::Int,
                                     HVCB_STATUS::Int,
                                     HVCB_ID::Int)
    
    nb = size(branch, 1)  # 支路数量
    nc = size(HVCB_data, 1)  # CB个数
    ng= size(gen, 1)  # 发电机数据数量

    # 收集所有元件连接点
    F_element = []
    T_element = []
    for i in 1:nc
        F_element = vcat(F_element, HVCB_data[i, HVCB_FROM_ELEMENT])
        T_element = vcat(T_element, HVCB_data[i, HVCB_TO_ELEMENT])
    end
    
    # 找到多个CB共同连接的点
    total_element = vcat(F_element, T_element)
    repeated_elements = unique(filter(x -> count(x .== total_element) > 1, total_element))
    length_repeated_element = length(repeated_elements)

    # 初始化数据结构
    dict_CB_CB = Dict()
    delete_bus_second = Int[]
    delete_HVCB_FIRST = String[]

    # 处理每个重复点
    for i in 1:length_repeated_element
        for j in 1:nc
            # 处理FROM端重复点
            if (repeated_elements[i] == HVCB_data[j,HVCB_FROM_ELEMENT] && 
                HVCB_data[j,HVCB_STATUS] == "Closed")
                for k in 1:nb
                    if (HVCB_data[j,HVCB_TO_ELEMENT] == branch[k,FBUS] || 
                        HVCB_data[j,HVCB_TO_ELEMENT] == branch[k,TBUS]) && 
                        isempty(intersect(repeated_elements, HVCB_data[j,HVCB_TO_ELEMENT]))
                        
                        dict_CB_CB[HVCB_data[j,HVCB_TO_ELEMENT]] = HVCB_data[j,HVCB_FROM_ELEMENT]
                        push!(delete_bus_second, HVCB_data[j,HVCB_TO_ELEMENT])
                        push!(delete_HVCB_FIRST, HVCB_data[j,HVCB_ID])
                    end
                end
            end

            # 处理TO端重复点
            if (repeated_elements[i] == HVCB_data[j,HVCB_TO_ELEMENT] && 
                HVCB_data[j,HVCB_STATUS] == "Closed")
                for k in 1:nb
                    if (HVCB_data[j,HVCB_FROM_ELEMENT] == branch[k,FBUS] || 
                        HVCB_data[j,HVCB_FROM_ELEMENT] == branch[k,TBUS]) && 
                        isempty(intersect(repeated_elements, HVCB_data[j,HVCB_FROM_ELEMENT]))
                        
                        dict_CB_CB[HVCB_data[j,HVCB_FROM_ELEMENT]] = HVCB_data[j,HVCB_TO_ELEMENT]
                        push!(delete_bus_second, HVCB_data[j,HVCB_FROM_ELEMENT])
                        push!(delete_HVCB_FIRST, HVCB_data[j,HVCB_ID])
                    end
                end
            end
        end
    end

    # 更新branch节点连接关系
    for i in 1:nb
        if haskey(dict_CB_CB, branch[i,FBUS])
            branch[i,FBUS] = dict_CB_CB[branch[i,FBUS]]
        end
        if haskey(dict_CB_CB, branch[i,TBUS])
            branch[i,TBUS] = dict_CB_CB[branch[i,TBUS]]
        end
    end

     #更新发电机节点连接关系
     for i in 1:ng
        if haskey(dict_CB_CB, gen[i,GEN_BUS])
            gen_index = dict_CB_CB[gen[i,GEN_BUS]]
            bus[findall(bus[:,BUS_I].==gen_index),TYPE] = bus[findall(bus[:,BUS_I].==gen[i,GEN_BUS]),TYPE]
            gen[i,GEN_BUS] = gen_index
            
        end
    end

    # 删除冗余节点
    if !isempty(delete_bus_second)
        delete_bus_second_set = unique(delete_bus_second)
        bus = bus[findall(x -> !(x in delete_bus_second_set), bus[:, BUS_I]), :]
    end

    # 删除冗余CB
    if !isempty(delete_HVCB_FIRST)
        delete_HVCB_FIRST_set = unique(delete_HVCB_FIRST)
        HVCB_data = HVCB_data[findall(x -> !(x in delete_HVCB_FIRST_set), HVCB_data[:, HVCB_ID]), :]
    end

    return branch, bus, HVCB_data
end

"""
处理CB共同连接点，包括两次扫描处理以确保处理所有CB连接情况
输入:
- branch: 支路矩阵
- bus: 节点矩阵
- HVCB_data: CB数据
- FBUS, TBUS: 支路起始和终止节点索引
- BUS_I: 节点编号索引
- HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT: CB的起始和终止元件索引
- HVCB_STATUS: CB状态索引
- HVCB_ID: CB编号索引

返回:
- branch: 更新后的支路矩阵
- bus: 更新后的节点矩阵
- HVCB_data: 更新后的CB数据
"""
function process_all_cb_connections!(branch::Matrix{Float64}, 
                                   bus::Matrix{Float64}, 
                                   gen::Matrix{Float64},
                                   HVCB_data::DataFrame,
                                   FBUS::Int, 
                                   TBUS::Int, 
                                   BUS_I::Int,
                                   TYPE::Int,
                                   GEN_BUS::Int,
                                   HVCB_FROM_ELEMENT::Int,
                                   HVCB_TO_ELEMENT::Int,
                                   HVCB_STATUS::Int,
                                   HVCB_ID::Int)
    
    # 第一次处理
    branch, bus, HVCB_data = process_common_cb_connections!(
        branch, bus, gen, HVCB_data,
        FBUS, TBUS, BUS_I, TYPE, GEN_BUS,
        HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
        HVCB_STATUS, HVCB_ID
    )

    # 第二次处理，处理剩余的两个CB接在一起的情况
    branch, bus, HVCB_data = process_common_cb_connections!(
        branch, bus, gen, HVCB_data,
        FBUS, TBUS, BUS_I, TYPE, GEN_BUS,
        HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
        HVCB_STATUS, HVCB_ID
    )

    return branch, bus, HVCB_data
end

"""
处理单个CB连接的节点，更新branch连接关系并删除冗余节点和CB
输入:
- branch: 支路矩阵
- bus: 节点矩阵
- HVCB_data: CB数据
- FBUS, TBUS: 支路起始和终止节点索引
- BUS_I: 节点编号索引
- HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT: CB的起始和终止元件索引
- HVCB_STATUS: CB状态索引
- HVCB_ID: CB编号索引

返回:
- branch: 更新后的支路矩阵
- bus: 更新后的节点矩阵
- HVCB_data: 更新后的CB数据
"""
function process_single_cb_connections!(branch::Matrix{Float64}, 
                                     bus::Matrix{Float64}, 
                                     gen::Matrix{Float64},
                                     HVCB_data::DataFrame,
                                     FBUS::Int, 
                                     TBUS::Int, 
                                     BUS_I::Int,
                                     TYPE::Int,
                                     GEN_BUS::Int,
                                     HVCB_FROM_ELEMENT::Int,
                                     HVCB_TO_ELEMENT::Int,
                                     HVCB_STATUS::Int,
                                     HVCB_ID::Int)
    
    nb = size(branch, 1)  # 支路数量
    ng= size(gen, 1)  # 发电机数据数量
    nc = size(HVCB_data, 1)  # 高压断路器数据数量
    dict_CB = Dict()  # 初始化节点字典
    delete_bus = Int[]  # 存储需要删除的节点
    delete_HVCB = String[]  # 存储已经计算过的HVCB
    
    # 遍历每个CB
    for i in 1:nc
        for j in 1:nb
            # 检查TO_ELEMENT与FBUS的匹配
            if HVCB_data[i, HVCB_TO_ELEMENT] == branch[j, FBUS] && 
               HVCB_data[i, HVCB_STATUS] == "Closed"
                dict_CB[HVCB_data[i, HVCB_TO_ELEMENT]] = HVCB_data[i, HVCB_FROM_ELEMENT]
                push!(delete_bus, branch[j, FBUS])
                push!(delete_HVCB, HVCB_data[i, HVCB_ID])
                break
            end
            
            # 检查TO_ELEMENT与TBUS的匹配
            if HVCB_data[i, HVCB_TO_ELEMENT] == branch[j, TBUS] && 
               HVCB_data[i, HVCB_STATUS] == "Closed"
                dict_CB[HVCB_data[i, HVCB_TO_ELEMENT]] = HVCB_data[i, HVCB_FROM_ELEMENT]
                push!(delete_bus, branch[j, TBUS])
                push!(delete_HVCB, HVCB_data[i, HVCB_ID])
                break
            end
            
            # 检查FROM_ELEMENT与FBUS的匹配
            if HVCB_data[i, HVCB_FROM_ELEMENT] == branch[j, FBUS] && 
               HVCB_data[i, HVCB_STATUS] == "Closed"
                dict_CB[HVCB_data[i, HVCB_FROM_ELEMENT]] = HVCB_data[i, HVCB_TO_ELEMENT]
                push!(delete_bus, branch[j, FBUS])
                push!(delete_HVCB, HVCB_data[i, HVCB_ID])
                break
            end
            
            # 检查FROM_ELEMENT与TBUS的匹配
            if HVCB_data[i, HVCB_FROM_ELEMENT] == branch[j, TBUS] && 
               HVCB_data[i, HVCB_STATUS] == "Closed"
                dict_CB[HVCB_data[i, HVCB_FROM_ELEMENT]] = HVCB_data[i, HVCB_TO_ELEMENT]
                push!(delete_bus, branch[j, TBUS])
                push!(delete_HVCB, HVCB_data[i, HVCB_ID])
                break
            end
        end
    end

    # 更新branch节点连接关系
    for i in 1:nb
        if haskey(dict_CB, branch[i,FBUS])
            branch[i,FBUS] = dict_CB[branch[i,FBUS]]
        end
        if haskey(dict_CB, branch[i,TBUS])
            branch[i,TBUS] = dict_CB[branch[i,TBUS]]
        end
    end

    #更新发电机节点连接关系
    for i in 1:ng
        if haskey(dict_CB, gen[i,GEN_BUS])
            gen_index = dict_CB[gen[i,GEN_BUS]]
            bus[findall(bus[:,BUS_I].==gen_index),TYPE] = bus[findall(bus[:,BUS_I].==gen[i,GEN_BUS]),TYPE]
            gen[i,GEN_BUS] = gen_index
            
        end
    end

    # 删除冗余节点
    if !isempty(delete_bus)
        delete_bus_set = unique(delete_bus)  # 去重，避免重复删除
        bus = bus[findall(x -> !(x in delete_bus_set), bus[:, BUS_I]), :]
    end

    # 删除已处理的CB
    if !isempty(delete_HVCB)
        delete_HVCB_set = unique(delete_HVCB)  # 去重，避免重复删除
        HVCB_data = HVCB_data[findall(x -> !(x in delete_HVCB_set), HVCB_data[:, HVCB_ID]), :]
    end

    return branch, bus, HVCB_data
end

"""
删除电力系统中没有连接支路的孤立节点
输入:
- branch: 支路矩阵
- bus: 节点矩阵
- FBUS, TBUS: 支路起始和终止节点索引
- BUS_I: 节点编号索引

返回:
- bus: 更新后的节点矩阵（已删除孤立节点）
"""
function remove_isolated_buses!(branch::Matrix{Float64}, 
                              bus::Matrix{Float64},
                              FBUS::Int,
                              TBUS::Int,
                              BUS_I::Int)
    
    nb = size(branch, 1)    # 支路数量
    nbus = size(bus, 1)     # 节点数量
    delete_bus_new = Int[]  # 用于存储需要删除的节点编号
    
    # 遍历所有节点
    for i in 1:nbus
        count_branch = 0  # 当前节点的支路连接计数
        
        # 检查每个节点与支路的连接情况
        for j in 1:nb
            # 统计与当前节点相连的支路数量
            if branch[j, FBUS] == bus[i, BUS_I]
                count_branch += 1
            end
            if branch[j, TBUS] == bus[i, BUS_I]
                count_branch += 1
            end
        end
        
        # 如果节点没有任何关联支路，将其加入删除列表
        if count_branch == 0
            push!(delete_bus_new, bus[i, BUS_I])
        end
    end
    
    # 删除所有孤立节点
    if !isempty(delete_bus_new)
        bus = bus[findall(x -> !(x in delete_bus_new), bus[:, BUS_I]), :]
    end
    
    return bus
end
"""
重新编号电力系统中的节点，并确保支路的起始和终止节点编号按升序排列
输入:
- branch: 支路矩阵
- bus: 节点矩阵
- FBUS, TBUS: 支路起始和终止节点索引
- BUS_I: 节点编号索引

返回:
- branch: 更新后的支路矩阵（节点编号已更新）
- bus: 更新后的节点矩阵（节点编号已更新）
- dict_new: 新旧节点编号的映射字典
"""
function renumber_buses!(branch::Matrix{Float64}, 
                        bus::Matrix{Float64},
                        FBUS::Int,
                        TBUS::Int,
                        BUS_I::Int)
    
    # 创建新的连续编号
    dict_index_new = collect(1:size(bus,1))
    
    # 创建旧编号到新编号的映射字典
    dict_new = Dict(zip(bus[:,BUS_I], dict_index_new))
    
    # 更新节点矩阵中的编号
    bus[:,BUS_I] = dict_index_new
    
    # 更新支路矩阵中的起始和终止节点编号
    branch[:,FBUS] = map(k -> dict_new[k], branch[:,FBUS])
    branch[:,TBUS] = map(k -> dict_new[k], branch[:,TBUS])
    
    # 确保支路的起始节点编号小于终止节点编号
    branch[:, FBUS], branch[:, TBUS] = min.(branch[:, FBUS], branch[:, TBUS]), 
                                      max.(branch[:, FBUS], branch[:, TBUS])
    
    return branch, bus, dict_new
end

"""
处理电力系统中的并联支路，合并阻抗并删除重复支路
输入:
- branch: 支路矩阵
- FBUS, TBUS: 支路起始和终止节点索引
- R, X, B: 支路电阻、电抗和电纳索引

返回:
- branch: 更新后的支路矩阵（并联支路已合并）
"""
function merge_parallel_branches!(branch::Matrix{Float64},
                                FBUS::Int,
                                TBUS::Int,
                                R::Int,
                                X::Int,
                                B::Int)
    
    # 合并并联支路的阻抗
    for i in 1:size(branch,1)
        for j in i+1:size(branch,1)
            if (branch[i,FBUS] == branch[j,FBUS] && 
                branch[i,TBUS] == branch[j,TBUS])
                # 对并联支路，阻抗和电纳采用并联公式
                z1 = complex(branch[i,R], branch[i,X])
                z2 = complex(branch[j,R], branch[j,X])
                z_parallel = 1 / (1/z1 + 1/z2)
                
                # 更新合并后的阻抗值
                branch[i,R] = real(z_parallel)
                branch[i,X] = imag(z_parallel)
                # 电纳直接相加
                branch[i,B] = branch[i,B] + branch[j,B]
            end
        end
    end
    
    # 删除重复支路
    # 步骤1：创建唯一标识符
    keys = Tuple.(eachrow(branch[:, 1:2]))
    
    # 步骤2：找出唯一的键值
    unique_keys = unique(keys)
    
    # 步骤3：找出每个唯一键第一次出现的位置
    unique_indices = [findfirst(isequal(k), keys) for k in unique_keys]
    
    # 步骤4：提取唯一的支路数据
    branch = branch[unique_indices, :]
    
    return branch
end
