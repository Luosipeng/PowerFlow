function dcbustypes(bus::Matrix{Float64}, gen::Matrix{Float64})
    # constants
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, 
        VA, BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN,PER_CONSUMER) = idx_dcbus();
        (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, PC1,
        PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, 
        RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
         COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN,GEN_AREA) = idx_gen();

    # get generator status
    nb = size(bus, 1)
    ng = size(gen, 1)
    Cg = sparse(gen[:, GEN_BUS], 1:ng, gen[:, GEN_STATUS] .> 0, nb, ng)  # gen connection matrix
    bus_gen_status = Cg * ones(ng, 1)  # number of generators at each bus that are ON
    
    # form index lists for slack, PV, and PQ buses
    bus_gen_status = vec(bus_gen_status)
    map!(x -> x != 0 ? true : x, bus_gen_status, bus_gen_status)
    ref = findall(bus[:, BUS_TYPE] .== REF .* bus_gen_status )  # reference bus index
    p  = findall(bus[:, BUS_TYPE] .== P  )  # P bus indices

    return ref, p
end
