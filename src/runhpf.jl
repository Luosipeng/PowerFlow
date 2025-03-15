function runhpf(mpc, opt)
    # 准备AC系统数据
    mpc1 = Dict("baseMVA" => mpc["baseMVA"],
                "bus" => mpc["busAC"],
                "gen" => mpc["genAC"],
                "load" => mpc["loadAC"],
                "branch" => mpc["branchAC"],
                "version" => "2")
    
    # 准备DC系统数据
    mpc2 = Dict("baseMVA" => mpc["baseMVA"],
                "bus" => mpc["busDC"],
                "gen" => mpc["genDC"],
                "load" => mpc["loadDC"],
                "branch" => mpc["branchDC"],
                "version" => "2")
    
    # 运行AC潮流计算
    mpc1 = PowerFlow.runpf(mpc1, opt)
    
    # 运行DC潮流计算
    mpc2 = PowerFlow.rundcpf(mpc2, opt)
    
    # 合并结果，包含两个系统的迭代次数和求解状态
    mpc = Dict(
        "baseMVA" => mpc["baseMVA"],
        "busAC" => mpc1["bus"],
        "genAC" => mpc1["gen"],
        "branchAC" => mpc1["branch"],
        "busDC" => mpc2["bus"],
        "genDC" => mpc2["gen"],
        "branchDC" => mpc2["branch"],
        "loadAC" => mpc1["load"],
        "loadDC" => mpc2["load"],  # 修正：这里应该是loadDC而不是iterations
        "version" => "2",
        # 添加迭代次数和求解状态
        "iterations" => Dict(
            "AC" => mpc1["iterations"],
            "DC" => mpc2["iterations"]
        ),
        "success" => Dict(
            "AC" => mpc1["success"],
            "DC" => mpc2["success"]
        )
    )
    
    return mpc
end
