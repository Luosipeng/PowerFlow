function find_islands(mpc)
    # 获取所有母线编号
    bus_ids = mpc["bus"][:, 1]
    n_bus = length(bus_ids)
    
    # 创建母线编号到索引的映射
    bus_id_to_idx = Dict{Int, Int}()
    for (idx, bus_id) in enumerate(bus_ids)
        bus_id_to_idx[Int(bus_id)] = idx
    end
    
    # 获取母线类型索引
    PQ, PV, REF = PowerFlow.idx_bus()[1:3]
    
    # 创建邻接矩阵
    adj = zeros(Int, n_bus, n_bus)
    
    # 只考虑状态为1的支路
    for branch in eachrow(mpc["branch"])
        if branch[11] == 1  # BR_STATUS = 11
            f_bus_id = Int(branch[1])
            t_bus_id = Int(branch[2])
            
            # 使用映射获取正确的索引
            f_idx = bus_id_to_idx[f_bus_id]
            t_idx = bus_id_to_idx[t_bus_id]
            
            adj[f_idx, t_idx] = 1
            adj[t_idx, f_idx] = 1
        end
    end
    
    # 使用DFS找到连通分量
    visited = falses(n_bus)
    groups = Vector{Vector{Int}}()
    
    # 首先找到所有连通分量
    for i in 1:n_bus
        if !visited[i]
            component = Int[]
            stack = [i]
            visited[i] = true
            
            while !isempty(stack)
                node_idx = pop!(stack)
                node_id = Int(bus_ids[node_idx])  # 转换回原始母线编号
                push!(component, node_id)
                
                # 检查相邻节点
                for neighbor_idx in 1:n_bus
                    if adj[node_idx, neighbor_idx] == 1 && !visited[neighbor_idx]
                        push!(stack, neighbor_idx)
                        visited[neighbor_idx] = true
                    end
                end
            end
            
            push!(groups, sort(component))
        end
    end
    
    # 找出孤立节点和全PQ节点组
    isolated = Int[]
    groups_to_remove = Int[]
    
    # 检查每个组
    for (idx, group) in enumerate(groups)
        if length(group) == 1
            # 处理单节点组
            node_id = group[1]
            node_idx = bus_id_to_idx[node_id]
            connections = sum(adj[node_idx, :])
            
            # 找到对应的母线在mpc["bus"]中的行
            bus_row = findfirst(x -> Int(x) == node_id, mpc["bus"][:, 1])
            bus_type = Int(mpc["bus"][bus_row, 2])
            
            if connections == 0 && bus_type == PQ
                # 孤立的PQ节点移到isolated
                push!(isolated, node_id)
                push!(groups_to_remove, idx)
            end
        else
            # 检查多节点组是否全是PQ节点
            all_pq = true
            for node_id in group
                # 找到对应的母线在mpc["bus"]中的行
                bus_row = findfirst(x -> Int(x) == node_id, mpc["bus"][:, 1])
                bus_type = Int(mpc["bus"][bus_row, 2])
                
                if bus_type == PV || bus_type == REF
                    all_pq = false
                    break
                end
            end
            
            if all_pq
                # 如果全是PQ节点，将整个组移到isolated
                append!(isolated, group)
                push!(groups_to_remove, idx)
            end
        end
    end
    
    # 从后向前删除组，以避免索引变化带来的问题
    sort!(groups_to_remove, rev=true)
    for idx in groups_to_remove
        deleteat!(groups, idx)
    end
      
    # 返回结果
    return groups, isolated
end
