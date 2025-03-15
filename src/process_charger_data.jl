function process_charger_data(Charger_data, gen, dict_bus, Dict_busdc,busdc,bus)
    #Write a function to process the charger data
    #Call the charger indexing function
    (Charger_ID,Charger_inservice,Charger_state,Charger_Felement,Charger_Telement,Charger_ACKV,Charger_DCV,Charger_kva,Charger_dckw,Charger_dceff,Charger_mode)=PowerFlow.charger_idx()
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA,
     BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN,PER_CONSUMER)=PowerFlow.idx_dcbus()
     (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, STATUS, PMAX, PMIN, PC1,
     PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP10, RAMP30, 
     RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
      COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN,GEN_AREA) = PowerFlow.idx_gen();

    #Filter the charger data
    Charger_data=Charger_data[Charger_data[:,Charger_inservice].=="true",:]
    Charger_data=filter(x->x[Charger_Felement] !==missing,Charger_data)
    Charger_data=filter(x->x[Charger_Telement] !==missing,Charger_data)

    #Change the Felement and Telement to bus index
    Charger_data[:,Charger_Felement]=map(x->dict_bus[x],Charger_data[:,Charger_Felement])
    Charger_data[:,Charger_Telement]=map(x->Dict_busdc[x],Charger_data[:,Charger_Telement])

    mode=Charger_data[:,Charger_mode]

    fixed_voltage=findall(mode[:].=="0")

    charger_dict=Dict()
    for i in fixed_voltage
        charger_dict[Charger_data[i,Charger_Felement]]=Charger_data[i,Charger_Telement]
    end

    busdc_v=Charger_data[fixed_voltage,Charger_Telement]
    bus_delete=Charger_data[fixed_voltage,Charger_Felement]
    
    for i in eachindex(busdc[:,1])
        if busdc[i,BUS_I] in busdc_v
            busdc[i,BUS_TYPE]=REF
        end
    end

    keep_indices = [!(bus[i, BUS_I] in bus_delete) for i in eachindex(bus[:,1] )]

    # 使用这个逻辑向量创建新矩阵
    bus = bus[keep_indices, :]

    rows_to_add = []
    for i in eachindex(gen[:,1])
        if gen[i, GEN_BUS] in bus_delete
            push!(rows_to_add, i)
        end
    end

    # 如果有需要添加的行，一次性连接
    if !isempty(rows_to_add)
        battery_gen = gen[rows_to_add, :]
    else
        battery_gen = zeros(0, 26)
    end
    battery_gen[:,GEN_BUS].=map(k->charger_dict[k],battery_gen[:,GEN_BUS])

    keep_indices_gen = [!(gen[i, GEN_BUS] in bus_delete) for i in eachindex(gen[:,1] )]

    gen=gen[keep_indices_gen,:]




    return gen, bus, busdc, battery_gen
end