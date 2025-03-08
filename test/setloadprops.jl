function setloadprops(mpc,elementtype,filed,value,dict_bus,dict_new;connectedname=nothing,Fbus=nothing,Tbus=nothing)
    row=0;
    col=0;
    bus=mpc["bus"]
    branch=mpc["branch"]
    gen=mpc["gen"]
    if elementtype=="Lumped Load"
        #Defualt PF=90%
        if filed=="MVA"
            col=3
        end
        row_temp=dict_bus[connectedname]
        row=dict_new[row_temp]
        bus[row,col]=round(value*0.9,digits=7)
        # bus[row,col]=round(value,digits=7)
        bus[row,col+1]=round(value*sin(acos(0.9)),digits=7)
        # bus[row,col+1]=0.0
    elseif elementtype=="XFORM2W"
        if filed=="SeckV"
            #Do nothing
        end
        if filed=="PrikV"
            #The initial prime voltage is 10kV
            
        end
        if filed=="MVA"
            brc_index=[]
            bus_F=dict_new[dict_bus[Fbus]]
            bus_T=dict_new[dict_bus[Tbus]]
            brc_index=findall((branch[:,1].==bus_F).& (branch[:,2].==bus_T))
            append!(brc_index,findall((branch[:,1].==bus_T).&(branch[:,2].==bus_F)))
            branch[brc_index,3]=branch[brc_index,3]*0.05/value
            branch[brc_index,4]=branch[brc_index,4]*0.05/value
            # bus[bus_F,8]=
        end
        if filed=="AnsiPosXR"
            #Default X/R=20
            brc_index=[]
            bus_F=dict_new[dict_bus[Fbus]]
            bus_T=dict_new[dict_bus[Tbus]]
            brc_index=findall((branch[:,1].==bus_F).& (branch[:,2].==bus_T))
            append!(brc_index,findall((branch[:,1].==bus_T).&(branch[:,2].==bus_F)))
            branch[brc_index,3]=branch[brc_index,3]*sqrt(1+20^2)/(sqrt(1+value^2))
            branch[brc_index,4]=branch[brc_index,4]*sqrt(1+20^2)*value/(sqrt(1+value^2)*20)
        end
    elseif elementtype=="CABLE"
        if filed=="LengthValue"
            #TODO:
            #Default length is 4000 ft
            brc_index=[]
            bus_F=dict_new[dict_bus[Fbus]]
            bus_T=dict_new[dict_bus[Tbus]]
            brc_index=findall((branch[:,1].==bus_F).& (branch[:,2].==bus_T))
            append!(brc_index,findall((branch[:,1].==bus_T).&(branch[:,2].==bus_F)))
            branch[brc_index,3]=branch[brc_index,3]*value/4000
            branch[brc_index,4]=branch[brc_index,4]*value/4000
        end
    elseif elementtype=="XLINE"
        if filed=="Length"
            #TODO:
            #Default length is 2000 ft
            brc_index=[]
            bus_F=dict_new[dict_bus[Fbus]]
            bus_T=dict_new[dict_bus[Tbus]]
            brc_index=findall((branch[:,1].==bus_F).& (branch[:,2].==bus_T))
            append!(brc_index,findall((branch[:,1].==bus_T).&(branch[:,2].==bus_F)))
            branch[brc_index,3]=branch[brc_index,3]*value/2000
            branch[brc_index,4]=branch[brc_index,4]*value/2000
        end
    end
    mpc["bus"]=bus
    mpc["branch"]=branch
    mpc["gen"]=gen
    return mpc
end

