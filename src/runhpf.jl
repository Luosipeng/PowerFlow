function runhpf(mpc, opt)
    mpc1 = Dict("baseMVA" =>mpc["baseMVA"],"bus" => mpc["busAC"],"gen" => mpc["genAC"],"load"=>mpc["loadAC"],"branch" => mpc["branchAC"],"version"=>"2")
    mpc2 = Dict("baseMVA" =>mpc["baseMVA"],"bus" => mpc["busDC"],"gen" => mpc["genDC"],"load"=>mpc["loadDC"],"branch" => mpc["branchDC"],"version"=>"2")
    mpc1=runpf(mpc1, opt)
    opt["PF"]["DC"]=1
    mpc2=rundcpf(mpc2, opt)
    mpc =Dict("baseMVA" =>mpc["baseMVA"],"busAC" => mpc1["bus"],"genAC" => mpc1["gen"],"branchAC" => mpc1["branch"],"busDC" => mpc2["bus"],"genDC" => mpc2["gen"],"branchDC" => mpc2["branch"],"version"=>"2","loadAC"=>mpc1["load"],"loadDC"=>mpc2["iterations"])
     return mpc1
 end