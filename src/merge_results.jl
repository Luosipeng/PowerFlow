# 简单合并孤岛的潮流计算结果
function merge_results(results)
    merged_result = Dict{String, Any}()
    
    # 合并基本结果字段
    merged_result["success"] = all([r["success"] for r in results])
    merged_result["iterations"] = maximum([r["iterations"] for r in results])
    
    # 合并主要数据矩阵并按第一列排序
    for key in ["bus", "branch", "gen", "gencost"]
        # 收集所有结果中的相应矩阵
        matrices = [r[key] for r in results if haskey(r, key)]
        
        if !isempty(matrices)
            # 垂直连接所有矩阵
            combined = vcat(matrices...)
            
            # 按第一列排序
            if !isempty(combined)
                sorted_indices = sortperm(combined[:, 1])
                merged_result[key] = combined[sorted_indices, :]
            else
                merged_result[key] = combined
            end
        end
    end
    
    # 处理其他可能的字段
    for r in results
        for (key, value) in r
            if !(key in ["bus", "branch", "gen", "gencost", "success", "iterations"]) && !haskey(merged_result, key)
                merged_result[key] = value
            end
        end
    end
    area = size(results, 1)
    return merged_result, area
end
