function process_load_data(Load_data::DataFrame, bus::Matrix{Float64}, dict_bus::Dict, Ci::Vector=nothing, P_inv::Vector=nothing, Q_inv::Vector=nothing)
    #调用索引函数
    (load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent)=PowerFlow.load_idx()#负荷索引
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=PowerFlow.idx_ld()
    (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
    BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = idx_bus();
    #创建负载矩阵
    load=zeros(size(Load_data,1),8)
    load[:,LOAD_I]=eachindex(load[:,LOAD_I])
    load[:,LOAD_CND]=map(x->dict_bus[x],Load_data[:,ConectedID])
    load[:,LOAD_STATUS]=(Load_data[:,load_inservice].=="Yes").+0
    load[:,LOAD_PD]=(Load_data[:,load_kva].*parse.(Float64,Load_data[:,load_pf])./100)./1000
    load[:,LOAD_QD]=Load_data[:,load_kva].*sqrt.(1 .-(parse.(Float64,Load_data[:,load_pf])./100).^2)./1000
    load[:,LOADZ_PERCENT]=1 .-Load_data[:,Pload_percent]./100
    load[:,LOADI_PERCENT].=0
    load[:,LOADP_PERCENT]=Load_data[:,Pload_percent]./100

    #处理逆变器传输功率
    if P_inv!==nothing
        inverter_connected_bus=map(x->dict_bus[x],Ci)
        for i in inverter_connected_bus
            if(i in load[:,LOAD_CND])
                idx=findall(x->x==i,load[:,LOAD_CND])
                load[idx,LOADP_PERCENT]=(load[idx,LOAD_PD].*load[idx,LOADP_PERCENT].-P_inv[inverter_connected_bus.==i]./1000)./(load[idx,LOAD_PD].-P_inv[inverter_connected_bus.==i]./1000)
                # load[idx,LOADI_PERCENT]=(load[idx,LOAD_PD].*load[idx,LOADI_PERCENT].+P_inv[inverter_connected_bus.==i]./1000)./(load[idx,LOAD_PD].+P_inv[inverter_connected_bus.==i]./1000)
                load[idx,LOADI_PERCENT].=0
                load[idx,LOADZ_PERCENT]=1 .-load[idx,LOADP_PERCENT].-load[idx,LOADI_PERCENT]

                load[idx,LOAD_PD].-=P_inv[inverter_connected_bus.==i]./1000
                load[idx,LOAD_QD].-=Q_inv[inverter_connected_bus.==i]./1000
                
                bus[bus[:,BUS_I].==i,PD] .= load[idx,LOAD_PD]
                bus[bus[:,BUS_I].==i,QD] .= load[idx,LOAD_QD]

            else
                load_inv=zeros(1,8)
                load_inv[LOAD_I]=size(load,1)+1
                load_inv[LOAD_CND]=i
                load_inv[LOAD_STATUS]=1
                load_inv[:,LOAD_PD].=-P_inv[inverter_connected_bus.==i]./1000
                load_inv[:,LOAD_QD].=-Q_inv[inverter_connected_bus.==i]./1000
                load_inv[LOADZ_PERCENT]=0
                load_inv[LOADI_PERCENT]=0
                load_inv[LOADP_PERCENT]=1.0
                load=vcat(load,load_inv)
                bus[bus[:,BUS_I].==i,PD] .= load_inv[LOAD_PD]
                bus[bus[:,BUS_I].==i,QD] .= load_inv[LOAD_QD]
            end
        end
    end
    return load,bus
end

function update_load_bus(load, node_mapping)
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=idx_ld()
    for i in eachindex(load[:,LOAD_CND])
        load[i,LOAD_CND]=node_mapping[load[i,LOAD_CND]]
    end
    return load
    
end