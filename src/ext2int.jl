"""
    Convert the data from external format to internal format
"""
function ext2int(bus::Matrix{Float64}, gen::Matrix{Float64}, branch::Matrix{Float64}, load::Matrix{Float64})
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = idx_bus();
    (F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, BR_STATUS, ANGMIN,
    ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF, MU_ST, MU_ANGMIN, MU_ANGMAX, LAMBDA, SW_TIME, RP_TIME, BR_TYPE, BR_AREA) = idx_brch()
         (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, PC1,
         PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, 
         RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
          COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN,GEN_AREA) = idx_gen();
          (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=idx_ld()
    #TODO: determine which buses, branches, gens are connected & in-service
    gen = gen[gen[:, 8] .!= 0, :]
    branch = branch[branch[:, 11] .!= 0, :]
    # create map of external bus numbers to bus indices
    i2e = Int.(bus[:, BUS_I])  # 确保i2e是整数类型
    e2i = sparsevec(zeros(Int, Int(maximum(i2e))))
    e2i[Int.(i2e)] = 1:size(bus, 1)
    # renumber buses consecutively
    bus[:, BUS_I] = e2i[bus[:, BUS_I]]
    gen[:, GEN_BUS] = e2i[gen[:, GEN_BUS]]
    branch[:, F_BUS] = e2i[branch[:, F_BUS]]
    branch[:, T_BUS] = e2i[branch[:, T_BUS]]
    load[:, LOAD_CND] = e2i[load[:, LOAD_CND]]
    return bus, gen, branch, load, i2e
end
