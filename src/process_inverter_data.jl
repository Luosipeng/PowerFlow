function process_inverter_data(Inverter_data::DataFrame)
    #Call inverter indexing function
    (inverter_ID,inverter_inservice,inverter_Felement,inverter_Telement,inverter_eff,inverter_Pac,inverter_Qac,inverter_Smax,inverter_Pmax,
    inverter_Qmax,inverter_generator_V1,inverter_generator_V2,inverter_generator_V3,inverter_generator_P1,inverter_generator_P2,
    inverter_generator_P3,inverter_charger_V1,inverter_charger_V2,inverter_charger_V3,inverter_charger_P1,inverter_charger_P2,inverter_charger_P3)=PowerFlow.inverter_idx()#逆变器索引

    #Delete the problematic inverters and find the inserviced inverters
    Inverter_data=Inverter_data[findall(Inverter_data[:,inverter_inservice].!=0),:]
    Inverter_data = filter(row -> row[inverter_Felement] !== missing, Inverter_data)
    Inverter_data = filter(row -> row[inverter_Felement] !== missing, Inverter_data)

    #Find which buses are connected to inverters
    Ci=Inverter_data[:,inverter_Felement]
    Cr=Inverter_data[:,inverter_Telement]
    P_inv=parse.(Float64,Inverter_data[:,inverter_Pac])
    Q_inv=parse.(Float64,Inverter_data[:,inverter_Qac])
    Smax_inv=parse.(Float64,Inverter_data[:,inverter_Smax])
    Pmax_inv=parse.(Float64,Inverter_data[:,inverter_Pmax])
    Qmax_inv=parse.(Float64,Inverter_data[:,inverter_Qmax])
    eff_inv=parse.(Float64,Inverter_data[:,inverter_eff])

    #process the PV curve data
    #generation curve
    generator_V1=parse.(Float64,Inverter_data[:,inverter_generator_V1])
    generator_V2=parse.(Float64,Inverter_data[:,inverter_generator_V2])
    generator_V3=parse.(Float64,Inverter_data[:,inverter_generator_V3])
    generator_P1=parse.(Float64,Inverter_data[:,inverter_generator_P1])
    generator_P2=parse.(Float64,Inverter_data[:,inverter_generator_P2])
    generator_P3=parse.(Float64,Inverter_data[:,inverter_generator_P3])

    #absorption curve
    charger_V1=parse.(Float64,Inverter_data[:,inverter_charger_V1])
    charger_V2=parse.(Float64,Inverter_data[:,inverter_charger_V2])
    charger_V3=parse.(Float64,Inverter_data[:,inverter_charger_V3])
    charger_P1=parse.(Float64,Inverter_data[:,inverter_charger_P1])
    charger_P2=parse.(Float64,Inverter_data[:,inverter_charger_P2])
    charger_P3=parse.(Float64,Inverter_data[:,inverter_charger_P3])

    #create the PV curve functions
    PV_generation_curve1=create_linear_function(generator_V1,generator_P1,generator_V2,generator_P2)
    PV_generation_curve2=create_linear_function(generator_V2,generator_P2,generator_V3,generator_P3)
    PV_absorption_curve1=create_linear_function(charger_V1,charger_P1,charger_V2,charger_P2)
    PV_absorption_curve2=create_linear_function(charger_V2,charger_P2,charger_V3,charger_P3)
    P_inv_dc=zeros(length(P_inv))
    for i in eachindex(P_inv)
        if P_inv[i]>0
            P_inv_dc[i]=P_inv[i]/eff_inv[i]*100
        else
            P_inv_dc[i]=P_inv[i]*eff_inv[i]/100
        end
    end
    # P_inv_dc=P_inv./eff_inv.*100
    return Ci,Cr,P_inv,Q_inv,Smax_inv,Pmax_inv,Qmax_inv,P_inv_dc,PV_generation_curve1,PV_generation_curve2,PV_absorption_curve1,PV_absorption_curve2
end

function create_linear_function(x1, y1, x2, y2)
    m = (y2 - y1) / (x2 - x1)  # 计算斜率
    b = y1 - m * x1  # 计算截距
    return x -> m * x + b  # 返回一个函数对象
end