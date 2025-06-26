using Documenter

# 清理 LOAD_PATH
filter!(x -> x ∉ ["../src/", ".."], LOAD_PATH)

# 重新添加源代码路径
push!(LOAD_PATH, "../src/")
push!(LOAD_PATH, "..")

using PowerFlow

# 生成文档
makedocs(
    clean = true,  # 添加这行来清理之前的构建
    sitename = "Power Flow Analysis",
    format = Documenter.HTML(
        prettyurls = false,
        # 移除 highlights 配置，使用默认值
    ),
    modules = [PowerFlow],
    pages = [
        "首页" => "index.md",
        "函数说明" => "functions.md",
        "主程序说明" => "main.md",
        "示例" => "examples.md"
    ],
    source = "src",
    build = "build",
    warnonly = true
)
