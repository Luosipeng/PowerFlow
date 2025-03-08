function makeSbus(baseMVA, bus, gen, Vm, load; dc=false, Sg=nothing, return_derivative=false)
    # Define named indices into bus, gen matrices
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, 
        VA, BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN) = PowerFlow.idx_bus();
    (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, PC1,
        PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, 
        RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
         COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN) = idx_gen();
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=PowerFlow.idx_ld()

    nb = size(bus, 1)
    pw_1=zeros(size(bus,1),1)
    pw_2=zeros(size(bus,1),1)
    pw_3=zeros(size(bus,1),1)
    pw_1[Int64.(load[:,LOAD_CND])]=load[:,LOADP_PERCENT]
    pw_2[Int64.(load[:,LOAD_CND])]=load[:,LOADI_PERCENT]
    pw_3[Int64.(load[:,LOAD_CND])]=load[:,LOADZ_PERCENT]
    # Get load parameters
    Sd = makeSdzip(baseMVA, bus,pw_1,pw_2,pw_3)

    if return_derivative
        if isempty(Vm)
            dSbus_dVm = spzeros(nb, nb)
        else
            dSbus_dVm = -(spdiagm(0 => Sd.i + 2 .* Vm .* Sd.z))
        end
        return dSbus_dVm
    else
        # Compute per-bus generation in p.u.
        on = findall(gen[:, GEN_STATUS] .> 0)  # which generators are on?
        gbus = gen[on, GEN_BUS]  # what buses are they at?
        ngon = length(on)
        Cg = sparse(gbus, 1:ngon, 1, nb, ngon)  # connection matrix
        # element i, j is 1 if gen on(j) at bus i is ON
        if Sg !== nothing
            Sbusg = Cg * Sg[on]
        else
            Sbusg = Cg * (gen[on, PG] .+ 1im * gen[on, QG]) / baseMVA
        end

        if dc
            Vm = ones(nb,1)
        end
        # Compute per-bus loads in p.u.
        Sbusd = Sd.p .+ Sd.i .* Vm .+ Sd.z .* Vm.^2

        # Form net complex bus power injection vector
        # (power injected by generators + power injected by loads)
        Sbus = Sbusg - Sbusd
        return Sbus
    end
end
