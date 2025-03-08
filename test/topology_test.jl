using Graphs
using GraphPlot
using Measures

# 保持原有的图构建代码
nb = size(bus,1)
g = SimpleGraph(nb)
nbrch = size(branch,1)
nhvcb = size(hvcb,1)

# 创建一个字典来存储边的类型
edge_types = Dict()

# 添加 branch 的边并记录类型
for i in 1:nbrch
    add_edge!(g, branch[i,1], branch[i,2])
    edge_types[(branch[i,1], branch[i,2])] = "branch"
end

# 添加 hvcb 的边并记录类型
for i in 1:nhvcb
    add_edge!(g, hvcb[i,2], hvcb[i,3])
    edge_types[(hvcb[i,2], hvcb[i,3])] = "hvcb"
end

# 创建边的颜色数组
edge_colors = String[]
for e in edges(g)
    source = Graphs.src(e)
    dest = Graphs.dst(e)
    if haskey(edge_types, (source, dest))
        if edge_types[(source, dest)] == "branch"
            push!(edge_colors, "blue")  # branch边用蓝色
        else
            push!(edge_colors, "red")   # hvcb边用红色
        end
    else
        # 检查反向边
        if haskey(edge_types, (dest, source))
            if edge_types[(dest, source)] == "branch"
                push!(edge_colors, "blue")
            else
                push!(edge_colors, "red")
            end
        end
    end
end

# 获取布局坐标
locs_x, locs_y = spring_layout(g,
    C = 8,           # 斥力系数
    MAXITER = 100,   # 最大迭代次数
    INITTEMP = 2.0   # 初始温度
)

# 绘制图形
gplot(g, 
    locs_x, locs_y,         # 直接传入坐标
    edgestrokec=edge_colors, # 使用边颜色数组
    plot_size=(16cm, 12cm)   # 保持原有的画布大小
)
