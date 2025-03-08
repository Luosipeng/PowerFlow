"""
从Excel工作表中提取数据
    
参数:
- sheet_name::String: 工作表名称
- sheets_data::Dict{String, DataFrame}: 包含所有工作表数据的字典

返回:
- DataFrame: 提取的数据子集
"""
function extract_data(sheet_name::String, sheets_data::Dict{String, DataFrame})::DataFrame
    # 初始化计数器
    row_count::Int = 0
    col_count::Int = 0
    
    # 获取当前工作表
    current_sheet::DataFrame = sheets_data[sheet_name]
    
    # 计算有效行数
    for row_idx in eachindex(current_sheet[11:end, 1])
        if ismissing(current_sheet[row_idx + 10, 1])
            row_count = row_idx - 1
            break
        end
        row_count = row_idx
    end
    
    # 计算有效列数
    for col_idx in axes(current_sheet, 2)
        if ismissing(current_sheet[10, col_idx])
            col_count = col_idx - 1
            break
        end
        col_count = col_idx
    end
    
    # 返回截取的数据
    return current_sheet[11:row_count+10, 1:col_count]
end
