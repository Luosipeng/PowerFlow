function assign_dcbus_data(DCbus::DataFrame,DC_lumpedload::DataFrame,Battery::DataFrame,Cr::Vector,P_inv_dc::Vector{Float64},baseMVA::Float64)
    #Call indexing function 
    (DCBUS_ID,DCBUS_V,DCBUS_INSERVICE)=PowerFlow.dcbus_idx();
    (BATTERY_ID,BATTERY_INSERVICE,BATTERY_CONNECTED_BUS,BATTERY_CELLS,BATTERY_PACKS,BATTERY_STRINGS)=PowerFlow.battery_idx();
    (DCLOADID,DCLOADINSERVICE,DCLOADCONNECTEDBUS,DCLOADRATEDV,DCLOADKW)=PowerFlow.dcload_idx();
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA,
     BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN,PER_CONSUMER)=PowerFlow.idx_dcbus()
     (FBUS, TBUS, R, X, B, RATEA, RATEB, RATEC, RATIO, ANGLE, BRSTATUS, ANGMIN,
     ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF, MU_ST, MU_ANGMIN, MU_ANGMAX, LAMBDA, SW_TIME, RP_TIME, BR_TYPE, BR_AREA) = PowerFlow.idx_brch()
     
     (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, STATUS, PMAX, PMIN, PC1,
     PC2, QC1MIN, QC1MAX, QC2MIN, QC2MAX, RAMP_AGC, RAMP10, RAMP30, 
     RAMP_Q, APF, PW_LINEAR, POLYNOMIAL, MODEL, STARTUP, SHUTDOWN, NCOST,
      COST, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN,GEN_AREA) = PowerFlow.idx_gen();
      
    #Find inserviced  DC buses
    inservice=findall(DCbus[:,DCBUS_INSERVICE].=="true");

    #Expand the DC bus data using the battery data
    #Battery can be divided into a impedance and a voltage source

    if !isempty(Battery)
        battery_inserviced=findall(Battery[:,BATTERY_INSERVICE].=="true");
        Battery=Battery[battery_inserviced,:];
        """
        Default battery configuation:Rp=0.0025,Vpc=2.06,plates=5
        """
        Rp=0.0025
        Vpc=2.06
        plates=5
        Voc=Vpc*parse.(Float64,Battery[:,BATTERY_CELLS]).*parse.(Float64,Battery[:,BATTERY_PACKS])
        Vb=Voc
        # r=2*Rp/plates*parse.(Float64,Battery[:,BATTERY_CELLS]).*parse.(Float64,Battery[:,BATTERY_PACKS])./parse.(Float64,Battery[:,BATTERY_STRINGS])
        r=0.0245
        battery_branches=zeros(length(battery_inserviced),14)
    

        #Create the battery bus
        battery_bus = [string("Bus_b", i) for i in 1:length(battery_inserviced)]
    else
        battery_inserviced=Int[]
        battery_bus=String[]
        battery_branches=zeros(0,14)
        Vb=[]
        r=0
    end
    busdc=zeros(length(vcat(inservice,battery_inserviced)),13)
    busdc[:,BUS_I].=1:length(vcat(inservice,battery_inserviced)); #Assign new ID for all DC buses
    Dict_busdc=Dict(zip(vcat(DCbus[:,DCBUS_ID],battery_bus[:]),busdc[:,BUS_I]))

    #Assign P buses (type 1)
    busdc[:,BUS_TYPE].=1
    #Assign V buses (type 2)
    if !isempty(battery_bus)
        assign_v_dcbuses(busdc,battery_bus,Dict_busdc)
    end

    #Assign load data to buses
    assign_dcload_data(busdc,DC_lumpedload,Dict_busdc)

    dcload,busdc=process_dcload_data(busdc, DC_lumpedload,Dict_busdc,Cr,P_inv_dc)
    # Set voltage values and zone information
    busdc[:,BUS_AREA].=1
    busdc[:, VM] .= 1.0  # Voltage magnitude
    busdc[:, VA] .= 0    # Voltage angle
    busdc[:, BASE_KV] .= vcat(parse.(Float64,DCbus[inservice,DCBUS_V]),Vb)./1000  # Base voltage
    busdc[:, ZONE] .= 1  # Zone set to 1 for all buses

    # Set maximum and minimum voltage limits
    busdc[:, VMAX] .= 1.05
    busdc[:, VMIN] .= 0.8

    if !isempty(battery_bus)
        battery_branches[:,FBUS].=busdc[Int64.(map(k->Dict_busdc[k],battery_bus)),BUS_I]
        battery_branches[:,TBUS].=busdc[Int64.(map(k->Dict_busdc[k],Battery[:,BATTERY_CONNECTED_BUS])),BUS_I]
        battery_branches[:,R].=r*baseMVA/((0.001*parse(Float64,DCbus[1,DCBUS_V]))^2)
        battery_branches[:,X].=0
        battery_branches[:,B].=0
        battery_branches[:,RATEA].=100
        battery_branches[:,RATEB].=100
        battery_branches[:,RATEC].=100
        battery_branches[:,RATIO].=0
        battery_branches[:,ANGLE].=0
        battery_branches[:,BRSTATUS].=1
        battery_branches[:,ANGMIN].=-180
        battery_branches[:,ANGMAX].=180

        #Create a battery generator
        battery_gen=zeros(length(battery_inserviced),21)
        battery_gen[:,GEN_BUS].=busdc[Int64.(map(k->Dict_busdc[k],battery_bus)),BUS_I]
        battery_gen[:,PG].=0
        battery_gen[:,QG].=0
        battery_gen[:,QMAX].=300
        battery_gen[:,QMIN].=-300
        battery_gen[:,VG].=1
        battery_gen[:,MBASE].=100
        battery_gen[:,STATUS].=1
        battery_gen[:,PMAX].=250
        battery_gen[:,PMIN].=10
        battery_gen[:,PC1].=0
        battery_gen[:,PC2].=0
        battery_gen[:,QC1MIN].=0
        battery_gen[:,QC1MAX].=0
        battery_gen[:,QC2MIN].=0
        battery_gen[:,QC2MAX].=0
        battery_gen[:,RAMP_AGC].=0
        battery_gen[:,RAMP10].=0
        battery_gen[:,RAMP30].=0
        battery_gen[:,RAMP_Q].=0
        battery_gen[:,APF].=0
    else
        battery_gen=zeros(0,21)
        battery_branches=zeros(0,14)
    end


    return busdc,dcload,Dict_busdc,battery_branches,battery_gen
end

# Function to assign V buses (type 2) based on battery
function assign_v_dcbuses(busdc, battery_bus, Dict_busdc)
    #Call bus indexing function
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA,
     BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN,PER_CONSUMER)=PowerFlow.idx_dcbus()

    V_index=Int64.(map(k->Dict_busdc[k],battery_bus))
    busdc[V_index,BUS_TYPE].=2

end

# Function to assign load data to buses
function assign_dcload_data(busdc,DC_lumpedload,Dict_busdc)
    #Call indexing function
    (DCLOADID,DCLOADINSERVICE,DCLOADCONNECTEDBUS,DCLOADRATEDV,DCLOADKW,DCLOADPERCENTP,DCLOADPERCENTZ)=PowerFlow.dcload_idx()
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA,
     BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN,PER_CONSUMER)=PowerFlow.idx_dcbus()
    if !isempty(DC_lumpedload)

        #Find in-service DC loads
        load_inservice=findall(DC_lumpedload[:,DCLOADINSERVICE].=="true")
        DC_lumpedload=DC_lumpedload[load_inservice,:]

        #Find the connected bus for the DC load
        DC_load_index=Int64.(map(k->Dict_busdc[k],DC_lumpedload[:,DCLOADCONNECTEDBUS]))
        busdc[DC_load_index,PD].=parse.(Float64,DC_lumpedload[:,DCLOADKW])./1000
    end

    # #Find the connected bus for the inverter
    # inverter_index=Int64.(map(k->Dict_busdc[k],Cr))
    # busdc[inverter_index,PD].=busdc[inverter_index,PD].+P_inv_dc./1000
end

function process_dcload_data(bus, DC_lumpedload,Dict_busdc,Cr,P_inv_dc)
    #Call indexing functions 
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=PowerFlow.idx_ld()
    (DCLOADID,DCLOADINSERVICE,DCLOADCONNECTEDBUS,DCLOADRATEDV,DCLOADKW,DCLOADPERCENTP,DCLOADPERCENTZ)=PowerFlow.dcload_idx()
    (P, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA,
     BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN,PER_CONSUMER)=PowerFlow.idx_dcbus()

    if !isempty(DC_lumpedload)

        #Find in-service DC loads
        load_inservice=findall(DC_lumpedload[:,DCLOADINSERVICE].=="true")
        DC_lumpedload=DC_lumpedload[load_inservice,:]

        #Create a dcload matrix
        dcload=zeros(size(DC_lumpedload,1),8)
        dcload[:,LOAD_I].=1:size(dcload,1)
        dcload[:,LOAD_CND].=Int64.(map(k->Dict_busdc[k],DC_lumpedload[:,DCLOADCONNECTEDBUS]))
        dcload[:,LOAD_STATUS].=1
        dcload[:,LOAD_PD].=parse.(Float64,DC_lumpedload[:,DCLOADKW])./1000
        dcload[:,LOAD_QD].=0
        dcload[:,LOADZ_PERCENT].=parse.(Float64,DC_lumpedload[:,DCLOADPERCENTZ])./100
        dcload[:,LOADI_PERCENT].=0
        dcload[:,LOADP_PERCENT].=parse.(Float64,DC_lumpedload[:,DCLOADPERCENTP])./100
    end
    if(P_inv_dc!==nothing)
        #Find the connected bus for the inverter
        inverter_index=Int64.(map(k->Dict_busdc[k],Cr))
        for i in inverter_index
            if(i in dcload[:,LOAD_CND])
                idx=findall(x->x==i,dcload[:,LOAD_CND])
                dcload[idx,LOADP_PERCENT].=(dcload[idx,LOAD_PD].*dcload[idx,LOADP_PERCENT].+P_inv_dc[inverter_index.==i]./1000)./(dcload[idx,LOAD_PD].+P_inv_dc[inverter_index.==i]./1000)
                dcload[idx,LOADI_PERCENT].=0
                dcload[idx,LOADZ_PERCENT].=1 .-dcload[idx,LOADP_PERCENT].-dcload[idx,LOADI_PERCENT]

                dcload[idx,LOAD_PD].+=P_inv_dc[inverter_index.==i]./1000
                dcload[idx,LOAD_QD].+=0

                bus[bus[:,BUS_I].==i,PD] .= dcload[idx,LOAD_PD]
                bus[bus[:,BUS_I].==i,QD] .= dcload[idx,LOAD_QD]

            else
                P_add = P_inv_dc[inverter_index.==i][1]./1000
                bus[bus[:,BUS_I].==i,PD] .= P_add
                bus[bus[:,BUS_I].==i,QD] .= 0
                
                # 创建新行并添加到 dcload
                new_row = [size(dcload,1)+1, i, 1, P_add, 0, 0, 0, 1]'
                dcload = vcat(dcload, new_row)
            end
        end
    end
    return dcload, bus
end