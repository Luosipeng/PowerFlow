"""
   Main function to call the DC power flow function
    Input: case file
    Output: results of the power flow as a dictionary
    Example:
    bus, gen, branch = rundcpf(casefile)
"""
function rundcpf(mpc, opt::Dict{String})
   # Step 2.1: Define the data structures
    # Define named indices into bus, gen, branch matrices
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,
    VA, BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN) =  PowerFlow.idx_dcbus();
    (F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, 
    BR_STATUS, ANGMIN, ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF,
     MU_ST, MU_ANGMIN, MU_ANGMAX) = idx_brch()
     (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, PC1,
     PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, 
     RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
      COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN) = idx_gen();

    # Step 2.2: Convert the data into the required format
    baseMVA = mpc["baseMVA"];
    bus =  mpc["bus"];
    gen = mpc["gen"];
    branch = mpc["branch"];   
    load = mpc["load"];
    # convert the external data to internal data 
    (bus, gen, branch,i2e) = ext2int(bus, gen, branch);
    ## get bus index lists of each type of bus
    (ref, p) = dcbustypes(bus, gen);
    ## generator info
    on = findall(gen[:, GEN_STATUS] .> 0)  # which generators are on?
    gbus = gen[on, GEN_BUS]  # what buses are they at?
    # Step 2.3: Run the power flow
    ##-----  run the power flow  ----- 
    alg = opt["PF"]["PF_ALG"];
    its = 0;            ## total iterations
    ## initialize
    V0  = bus[:, VM]
    ## build admittance matrices
    (Ybus, Yf, Yt) = makeYbus(baseMVA, bus, branch)
    repeat=1;
    while (repeat>0)
        ## function for computing V dependent complex bus power injections
        ## (generation - load)
        Sbus = Vm -> makeSbus(baseMVA, bus, gen, Vm, load);
        if alg == "NR"
            V, success, iterations = newtondcpf(Ybus, Sbus, V0, ref, p, opt["PF"]["PF_TOL"], opt["PF"]["PF_MAX_IT"], opt["PF"]["NR_ALG"]);
            its += iterations;
        end
        bus, gen, branch = dcpfsoln(baseMVA, bus, gen, branch, load, Ybus, Yf, Yt, V, ref, p)
        repeat = 0;
    end
    bus, gen, branch, areas=PowerFlow.int2ext(i2e,bus,gen,branch)
    mpc["bus"] = bus
    mpc["gen"] = gen
    mpc["branch"] = branch
    mpc["iterations"] = its
    return mpc
end