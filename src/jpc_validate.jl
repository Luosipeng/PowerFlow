"""
jpc结构元件检验函数
检验元件包括：
(1)交流母线
(2)直流母线
(3)线路
(4)变压器
(5)发电机
(6)阻抗元件
(7)直流输电线路
(8)储能设备
(9)电压源换流器
"""
#TODO: 输入为dataframe
function validate_element(bus_data, gen_data, cable_data, transline_data, transformer_data, Load_data, Utility_data, HVCB_data, impedance_data, Inverter_data, DCbus, DC_impedance, DC_cable, Battery, DC_lumpedload)

    (EquipmentID,Voltage,Initial_Voltage,In_Service,Bus_Type)=PowerFlow.bus_idx()#节点母线索引
    (Cable_EquipeID,Cable_inservice,Cable_Felement,Cable_Telement,Cable_length,Cable_r1,Cable_x1,Cable_y1,Cable_perunit_length_value)=PowerFlow.cable_idx()#线缆索引
    (Line_EquipmentID,Line_length,Line_inservice,Line_Felement,Line_Telement,Line_r11,Line_x1,Line_y1)=PowerFlow.xline_idx()#传输线索引
    (Trans_EquipmentID,Trans_inservice,Trans_Pelement,Trans_Selement,prisecrated_Power,Trans_Pvoltage,Trans_Svoltage,Trans_Pos_value,Trans_Pos_XRrating)=PowerFlow.XFORM2W_idx()#变压器索引
    (load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent)=PowerFlow.load_idx()#负荷索引
    (Utility_EquipmentID,Utility_connected_ID,Utility_Inservice,Utility_Voltage,Utility_control_mode)=PowerFlow.utility_idx()#电网索引
    (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT, HVCB_INSERVICE, HVCB_STATUS) = PowerFlow.hvcb_idx()#高压断路器索引
    (DCBUS_ID,DCBUS_V,DCBUS_INSERVICE)=PowerFlow.dcbus_idx()#直流母线索引
    (DCLOADID,DCLOADINSERVICE,DCLOADCONNECTEDBUS,DCLOADRATEDV,DCLOADKW,DCLOADPERCENTP,DCLOADPERCENTZ)=PowerFlow.dcload_idx()#直流负载索引
    (inverter_ID,inverter_inservice,inverter_Felement,inverter_Telement,inverter_eff,inverter_Pac,inverter_Qac,inverter_Smax,inverter_Pmax,inverter_Qmax,inverter_generator_V1,inverter_generator_V2,inverter_generator_V3,inverter_generator_P1,inverter_generator_P2,inverter_generator_P3,inverter_charger_V1,inverter_charger_V2,inverter_charger_V3,inverter_charger_P1,inverter_charger_P2,inverter_charger_P3)=PowerFlow.inverter_idx()#逆变器索引
    (Battery_EquipmentID,Battery_connected_ID,Battery_Inservice,Battery_Voltage,Battery_control_mode)=PowerFlow.battery_idx()#电池索引

    # 验证母线
    all_valid = true
    failed_buses = String[]  # 用来存储失败的母线信息

    for i in eachindex(bus_data[:,EquipmentID])  
        validate_bus = matrix_row_to_bus(bus_data[i,:])
        try
            PowerFlow.validate_bus_parameters(
                validate_bus.vn_kv,
                validate_bus.bus_type,
                validate_bus.max_vm_pu,
                validate_bus.min_vm_pu,
                validate_bus.in_service
            )
        catch e
            all_valid = false
            # 将失败的母线信息添加到数组中
            push!(failed_buses, "母线 $(validate_bus.name) 验证失败: $(e.msg)")
        end
    end

    # 验证完成后输出结果
    if all_valid
        println("所有母线验证成功！")
    else
        println("部分母线验证失败：")
        # 打印所有失败的母线信息
        for error_msg in failed_buses
            println(error_msg)
        end
        # 可选：打印失败的母线数量
        println("共有 $(length(failed_buses)) 个母线验证失败。")
    end

    # 验证电缆线路
    if !isempty(cable_data)
        all_valid = true
        failed_branches = String[]  # 用来存储失败的线路信息
        for i in eachindex(cable_data[:,Cable_EquipeID])
            validate_line=matrix_row_to_cbline(cable_data[i,:])
            try
                PowerFlow.validate_line_parameters(
                    validate_line.length_km,
                    validate_line.r_ohm_per_km,
                    validate_line.x_ohm_per_km,
                    validate_line.c_nf_per_km,
                    validate_line.r0_ohm_per_km,
                    validate_line.x0_ohm_per_km,
                    validate_line.c0_nf_per_km,
                    validate_line.g_us_per_km,
                    validate_line.max_i_ka,
                    validate_line.parallel,
                    validate_line.df_star,
                    validate_line.line_type,
                    validate_line.max_loading_percent,
                    validate_line.endtemp_degree,
                    validate_line.in_service,
                    nothing,
                    validate_line.lambda_pu,
                    validate_line.tau_sw,
                    validate_line.taw_rp
                )
            catch e
                all_valid = false
                # 将失败的线路信息添加到数组中
                push!(failed_branches, "电缆 $(validate_line.name) 验证失败: $(e.msg)")
            end
        end

        # 验证完成后输出结果
        if all_valid
            println("所有电缆验证成功！")
        else
            println("部分电缆验证失败：")
            # 打印所有失败的线路信息
            for error_msg in failed_branches
                println(error_msg)
            end
            # 可选：打印失败的线路数量
            println("共有 $(length(failed_branches)) 个线路验证失败。")
        end
    end

    #验证传输线
    if !isempty(transline_data)
        all_valid = true
        failed_branches = String[]  # 用来存储失败的线路信息
        for i in eachindex(transline_data[:,Line_EquipmentID])
            validate_xline=matrix_row_to_xline(transline_data[i,:])
            try
                PowerFlow.validate_line_parameters(
                    validate_xline.length_km,
                    validate_xline.r_ohm_per_km,
                    validate_xline.x_ohm_per_km,
                    validate_xline.c_nf_per_km,
                    validate_xline.r0_ohm_per_km,
                    validate_xline.x0_ohm_per_km,
                    validate_xline.c0_nf_per_km,
                    validate_xline.g_us_per_km,
                    validate_xline.max_i_ka,
                    validate_xline.parallel,
                    validate_xline.df_star,
                    validate_xline.line_type,
                    validate_xline.max_loading_percent,
                    validate_xline.endtemp_degree,
                    validate_xline.in_service,
                    nothing,
                    validate_xline.lambda_pu,
                    validate_xline.tau_sw,
                    validate_xline.taw_rp
                )
            
            catch e
                all_valid = false
                # 将失败的线路信息添加到数组中
                push!(failed_branches, "传输线 $(validate_impedance.name) 验证失败: $(e.msg)")
            end
        end

        # 验证完成后输出结果
        if all_valid
            println("所有传输线验证成功！")
        else
            println("部分传输线验证失败：")
            # 打印所有失败的线路信息
            for error_msg in failed_branches
                println(error_msg)
            end
            # 可选：打印失败的线路数量
            println("共有 $(length(failed_branches)) 个传输线验证失败。")
        end
    end

    #验证变压器
    if !isempty(transformer_data)
        all_valid = true
        failed_branches = String[]  # 用来存储失败的线路信息
        for i in eachindex(transformer_data[:,Trans_EquipmentID])
            validate_transformer=matrix_row_to_transformer(transformer_data[i,:])
            try
                PowerFlow.validate_transformer_parameters(
                    validate_transformer.sn_mva,
                    validate_transformer.vn_hv_kv,
                    validate_transformer.vn_lv_kv,
                    validate_transformer.vk_percent,
                    validate_transformer.vkr_percent,
                    validate_transformer.pfe_kw,
                    validate_transformer.i0_percent,
                    validate_transformer.vk0_percent,
                    validate_transformer.vkr0_percent,
                    validate_transformer.mag0_percent,
                    validate_transformer.si0_hv_partial,
                    validate_transformer.vector_group,
                    validate_transformer.tap_side,
                    validate_transformer.tap_step_percent,
                    validate_transformer.tap_step_degree,
                    validate_transformer.parallel,
                    validate_transformer.max_loading_percent,
                    validate_transformer.df,
                    validate_transformer.in_service,
                    validate_transformer.oltc,
                    validate_transformer.power_station_unit,
                    validate_transformer.tap2_side,
                    validate_transformer.tap2_step_percent,
                    validate_transformer.tap2_step_degree,
                    validate_transformer.leakage_resistance_ratio_hv,
                    validate_transformer.leakage_reactance_ratio_hv,
                )
            catch e
                all_valid = false
                # 将失败的线路信息添加到数组中
                push!(failed_branches, "变压器 $(validate_transformer.name) 验证失败: $(e.msg)")
            end
        end

        # 验证完成后输出结果
        if all_valid
            println("所有变压器验证成功！")
        else
            println("部分变压器验证失败：")
            # 打印所有失败的线路信息
            for error_msg in failed_branches
                println(error_msg)
            end
            # 可选：打印失败的线路数量
            println("共有 $(length(failed_branches)) 个变压器验证失败。")
        end
    end

    # 验证阻抗元件
    if !isempty(impedance_data)
        
    end
    # 验证发电机
    if !isempty(gen_data)

    end

    # 验证外部电网
    if !isempty(Utility_data)
        all_valid = true
        failed_grid = String[]  
        for i in eachindex(Utility_data[:,Utility_EquipmentID])
            validate_grid=matrix_row_to_utility(Utility_data[i,:])
            try
                PowerFlow.validate_external_grid_parameters(
                    validate_grid.vm_pu,
                    validate_grid.s_sc_max_mva,
                    validate_grid.s_sc_min_mva,
                    validate_grid.rx_max,
                    validate_grid.rx_min,
                    validate_grid.r0x0_max,
                    validate_grid.x0x,
                    validate_grid.in_service,
                )
            catch e
                all_valid = false
                push!(failed_grid, "外部电网 $(validate_grid.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有外部电网验证成功！")
        else
            println("部分外部电网验证失败：")
            for error_msg in failed_grid
                println(error_msg)
            end
            println("共有 $(length(failed_grid)) 个外部电网验证失败。")
        end
    end

    #验证负荷
    if !isempty(Load_data)
        all_valid = true
        failed_load = String[]  
        for i in eachindex(Load_data[:,ConectedID])
            validate_load=matrix_row_to_load(Load_data[i,:])
            try
                PowerFlow.validate_load_parameters(
                    validate_load.p_mw,
                    validate_load.const_z_percent,
                    validate_load.const_i_percent,
                    validate_load.sn_mva,
                    validate_load.scaling,
                    validate_load.in_service,
                    validate_load.load_type,
                )
            catch e
                all_valid = false
                push!(failed_load, "负荷 $(validate_load.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有负荷验证成功！")
        else
            println("部分负荷验证失败：")
            for error_msg in failed_load
                println(error_msg)
            end
            println("共有 $(length(failed_load)) 个负荷验证失败。")
        end
    end

    # 验证高压断路器
    if !isempty(HVCB_data)
        all_valid = true
        failed_hvcb = String[]
        for i in eachindex(HVCB_data[:,HVCB_ID])
            validate_hvcb = matrix_row_to_hvcb(HVCB_data[i,:])
            try
                PowerFlow.validate_switch_parameters(
                    validate_hvcb.et,
                    validate_hvcb.switch_type,
                    validate_hvcb.closed,
                    validate_hvcb.in_ka
                )
            catch e
                all_valid = false
                push!(failed_hvcb, "高压断路器 $(validate_hvcb.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有高压断路器验证成功！")
        else
            println("部分高压断路器验证失败：")
            for error_msg in failed_hvcb
                println(error_msg)
            end
            println("共有 $(length(failed_hvcb)) 个高压断路器验证失败。")
        end
    end

    # 验证直流母线
    if !isempty(DCbus)
        all_valid = true
        failed_dc_bus = String[]
        for i in eachindex(DCbus[:,DCBUS_ID])
            validate_dc_bus = matrix_row_to_dcbus(DCbus[i,:])
            try
                PowerFlow.validate_dc_bus_parameters(
                    validate_dc_bus.vn_kv,
                    validate_dc_bus.bus_type,
                    validate_dc_bus.in_service
                )
            catch e
                all_valid = false
                push!(failed_dc_bus, "直流母线 $(validate_dc_bus.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有直流母线验证成功！")
        else
            println("部分直流母线验证失败：")
            for error_msg in failed_dc_bus
                println(error_msg)
            end
            println("共有 $(length(failed_dc_bus)) 个直流母线验证失败。")
        end
    end

    # 验证直流阻抗
    if !isempty(DC_impedance)
        
    end

    # 验证电池
    if !isempty(Battery)
        all_valid = true
        failed_battery = String[]
        for i in eachindex(Battery[:,Battery_EquipmentID])
            validate_battery = matrix_row_to_battery(Battery[i,:])
            try
                PowerFlow.validate_storage_parameters(
                    validate_battery.p_mw,
                    validate_battery.sn_mva,
                    validate_battery.scaling,
                    validate_battery.soc_percent,
                    validate_battery.in_service
                )
            catch e
                all_valid = false
                push!(failed_battery, "电池 $(validate_battery.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有电池验证成功！")
        else
            println("部分电池验证失败：")
            for error_msg in failed_battery
                println(error_msg)
            end
            println("共有 $(length(failed_battery)) 个电池验证失败。")
        end
    end

    # 验证直流负载
    if !isempty(DC_lumpedload)
       all_valid = true
        failed_dc_load = String[]
        for i in eachindex(DC_lumpedload[:,DCLOADID])
            validate_dc_load = matrix_row_to_dcload(DC_lumpedload[i,:])
            try
                PowerFlow.validate_load_parameters(
                    validate_dc_load.p_mw,
                    validate_dc_load.const_z_percent,
                    validate_dc_load.const_i_percent,
                    validate_dc_load.sn_mva,
                    validate_dc_load.scaling,
                    validate_dc_load.in_service,
                    validate_dc_load.load_type
                )
            catch e
                all_valid = false
                push!(failed_dc_load, "直流负载 $(validate_dc_load.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有直流负载验证成功！")
        else
            println("部分直流负载验证失败：")
            for error_msg in failed_dc_load
                println(error_msg)
            end
            println("共有 $(length(failed_dc_load)) 个直流负载验证失败。")
        end 
    end

    # 验证逆变器
    if !isempty(Inverter_data)
       all_valid = true
        failed_inverter = String[]
        for i in eachindex(Inverter_data[:,inverter_ID])
            validate_inverter = matrix_row_to_inverter(Inverter_data[i,:])
            try
                PowerFlow.validate_vsc_parameters(
                    validate_inverter.r_ohm,
                    validate_inverter.x_ohm,
                    validate_inverter.controllable,
                    validate_inverter.in_service,
                )
            catch e
                all_valid = false
                push!(failed_inverter, "逆变器 $(validate_inverter.name) 验证失败: $(e.msg)")
            end
        end

        if all_valid
            println("所有逆变器验证成功！")
        else
            println("部分逆变器验证失败：")
            for error_msg in failed_inverter
                println(error_msg)
            end
            println("共有 $(length(failed_inverter)) 个逆变器验证失败。")
        end 
    end
end

function matrix_row_to_bus(row::DataFrameRow)
    (EquipmentID,Voltage,Initial_Voltage,In_Service,Bus_Type)=PowerFlow.bus_idx()#节点母线索引
        # type_dict=Dict(0=>"n",PV=>"b",REF=>"m",NONE=>"NONE")
    return PowerFlow.Bus(
        row[EquipmentID],
        row[Voltage],
        "n",
        1.1,
        0.8,
        row[In_Service]=="Yes"
    )
end

function matrix_row_to_cbline(row::DataFrameRow)
    (Cable_EquipeID,Cable_inservice,Cable_Felement,Cable_Telement,Cable_length,
    Cable_r1,Cable_x1,Cable_y1,Cable_perunit_length_value)=PowerFlow.cable_idx()#线缆索引
    
    return PowerFlow.Line(
        row[Cable_EquipeID],
        row[Cable_length],
        row[Cable_r1],
        row[Cable_x1],
        row[Cable_y1],
        row[Cable_r1],
      3*row[Cable_x1],
        row[Cable_y1],
        0.0,
        1.0,
        1,
        1.0,
        "ol",
        1.0,
        27.0,
        row[Cable_inservice]=="Yes",
        0.0,
        0.0,
        0.0
    )
end

function matrix_row_to_xline(row::DataFrameRow)
    (Line_EquipmentID,Line_length,Line_inservice,Line_Felement,Line_Telement,Line_r11,Line_x1,Line_y1)=PowerFlow.xline_idx()#传输线索引
    return PowerFlow.Line(
        row[Line_EquipmentID],
        Float64(row[Line_length]),
        parse(Float64,row[Line_r11]),
        parse(Float64,row[Line_x1]),
        parse(Float64,row[Line_y1]),
        parse(Float64,row[Line_r11]),
        3*parse(Float64,row[Line_x1]),
        parse(Float64,row[Line_y1]),
        0.0,
        1.0,
        1,
        1.0,
        "ol",
        1.0,
        27.0,
        row[Line_inservice]=="Yes",
        0.0,
        0.0,
        0.0
    )
    
end

function matrix_row_to_transformer(row::DataFrameRow)
    (Trans_EquipmentID,Trans_inservice,Trans_Pelement,Trans_Selement,prisecrated_Power,
    Trans_Pvoltage,Trans_Svoltage,Trans_Pos_value,Trans_Pos_XRrating)=PowerFlow.XFORM2W_idx()#变压器索引

    return PowerFlow.Transformer(
        row[Trans_EquipmentID],
        row[prisecrated_Power],
        row[Trans_Pvoltage],
        row[Trans_Svoltage],
        1.0,
        1.0,
        0.01,
        0.01,
        0.01,
        0.01,
        0.01,
        0.01,
        "Dyn",
        "high",
        1.0,
        1.0,
        1,
        1.0,
        0.5,
        row[Trans_inservice]=="Yes",
        false,
        true,
        "low",
        1.0,
        1.0,
        1.0,
        1.0,
    )
end

function matrix_row_to_utility(row::DataFrameRow)
    (Utility_EquipmentID,Utility_connected_ID,Utility_Inservice,Utility_Voltage,Utility_control_mode)=PowerFlow.utility_idx()#电网索引
    return PowerFlow.ExternalGrid(
        row[Utility_EquipmentID],
        Float64(row[Utility_Voltage]),
        100.0,
        80.0,
        1.0,
        1.0,
        1.0,
        1.0,
        row[Utility_Inservice]=="Yes"
    )
    
end

function matrix_row_to_load(row::DataFrameRow)
    (load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent)=PowerFlow.load_idx()#负荷索引
    TYPE_DICT=Dict("Δ"=>"delta","Y"=>"wye")
    return PowerFlow.Load(
        row[load_EquipmentID],
        row[load_kva]*parse(Float64,row[load_pf])/100000,
        1.0-row[Pload_percent]/100,
        0.0,
        row[load_kva]/1000,
        1.0,
        row[load_inservice]=="Yes",
        TYPE_DICT[row[load_type]]  
    )
end

function matrix_row_to_dcbus(row::DataFrameRow)
    (DCBUS_ID,DCBUS_V,DCBUS_INSERVICE)=PowerFlow.dcbus_idx()#直流母线索引
    return PowerFlow.DcBus(
        row[DCBUS_ID],
        parse(Float64,row[DCBUS_V]),
        "n",
        row[DCBUS_INSERVICE]=="Yes"
    )
    
end

function matrix_row_to_hvcb(row::DataFrameRow)
    (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT, HVCB_INSERVICE, HVCB_STATUS) = PowerFlow.hvcb_idx()#高压断路器索引
    return PowerFlow.Switch(
        row[HVCB_ID],
        "b",
        "CB",
        row[HVCB_STATUS]=="Closed",
        1.0
    )
end

function matrix_row_to_battery(row::DataFrameRow)
    (Battery_EquipmentID,Battery_connected_ID,Battery_Inservice,Battery_Voltage,Battery_control_mode)=PowerFlow.battery_idx()#电池索引
    return PowerFlow.Storage(
        row[Battery_EquipmentID],
        120.0,
        150.0,
        1.0,
        0.8,
        row[Battery_Inservice]=="Yes"
    )
    
end

function matrix_row_to_dcload(row::DataFrameRow)
    (DCLOADID,DCLOADINSERVICE,DCLOADCONNECTEDBUS,DCLOADRATEDV,DCLOADKW,DCLOADPERCENTP,DCLOADPERCENTZ)=PowerFlow.dcload_idx()#直流负载索引
    return PowerFlow.Load(
        row[DCLOADID],
        parse(Float64,row[DCLOADKW])/1000,
        parse(Float64,row[DCLOADPERCENTZ])/100,
        0.0,
        parse(Float64,row[DCLOADKW])/1000,
        row[DCLOADINSERVICE]=="Yes",
        1.0,
        "wye"
    )
    
end

function matrix_row_to_inverter(row::DataFrameRow)
    (inverter_ID,inverter_inservice,inverter_Felement,inverter_Telement,inverter_eff,inverter_Pac,inverter_Qac,
    inverter_Smax,inverter_Pmax,inverter_Qmax,inverter_generator_V1,inverter_generator_V2,inverter_generator_V3,
    inverter_generator_P1,inverter_generator_P2,inverter_generator_P3,inverter_charger_V1,inverter_charger_V2,
    inverter_charger_V3,inverter_charger_P1,inverter_charger_P2,inverter_charger_P3)=PowerFlow.inverter_idx()#逆变器索引
    return PowerFlow.VoltageSourceConverter(
        row[inverter_ID],
        0.01,
        0.01,
        true,
        row[inverter_inservice]=="Yes"
    )
    
end