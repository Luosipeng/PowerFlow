

# 定义一个类型别名来表示 PV 曲线函数
PVCurveFunction = Function

# 定义 PV 曲线结构体
struct PVCurves
    generation_curve1::Union{PVCurveFunction, Nothing}
    generation_curve2::Union{PVCurveFunction, Nothing}
    absorption_curve1::Union{PVCurveFunction, Nothing}
    absorption_curve2::Union{PVCurveFunction, Nothing}
end

# 构造函数，用于创建空的 PV 曲线
PVCurves() = PVCurves(nothing, nothing, nothing, nothing)

"""
    Excel_to_IEEE_acdc(file_path, DCfile_path=nothing)

将 Excel 格式的电力系统数据转换为 IEEE 格式。
返回值：
- mpc: 包含系统数据的字典
- dict_bus: 母线映射字典
- node_mapping: 节点映射
- pv_curves: PV曲线数据结构（包含函数方法）
"""
function excel2jpc(file_path, DCfile_path=nothing)
    # 系统基准值
    baseMVA = 100.0
    baseKV = 10.0

    # 读取 AC 系统数据
    sheets_data = Dict{String, DataFrame}()
    XLSX.openxlsx(file_path) do wb
        for sheet_name in XLSX.sheetnames(wb)
            sheet = XLSX.getsheet(wb, sheet_name)
            sheets_data[sheet_name] = DataFrame(sheet[:], :auto)
        end
    end

    # 读取 DC 系统数据（如果存在）
    DCsheets_data = Dict{String, DataFrame}()
    if DCfile_path !== nothing
        XLSX.openxlsx(DCfile_path) do wb
            for sheet_name in XLSX.sheetnames(wb)
                sheet = XLSX.getsheet(wb, sheet_name)
                DCsheets_data[sheet_name] = DataFrame(sheet[:], :auto)
            end
        end
    end

    # 获取 HVCB 索引
    (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT, HVCB_INSERVICE, HVCB_STATUS) = PowerFlow.hvcb_idx()

    # 提取 AC 系统组件数据
    bus_data = PowerFlow.extract_data("Bus", sheets_data)
    gen_data = PowerFlow.extract_data("Synchronous Generator", sheets_data)
    cable_data = PowerFlow.extract_data("Cable", sheets_data)
    transline_data = PowerFlow.extract_data("Transmission Line", sheets_data)
    transformer_data = PowerFlow.extract_data("Two-Winding Transformer", sheets_data)
    Load_data = PowerFlow.extract_data("Lumped Load", sheets_data)
    Utility_data = PowerFlow.extract_data("Utility", sheets_data)
    HVCB_data = PowerFlow.extract_data("HVCB", sheets_data)
    impedance_data = PowerFlow.extract_data("Impedance", sheets_data)

    # 提取 DC 系统组件数据
    if !isempty(DCsheets_data)
        Inverter_data = PowerFlow.extract_dcdata("INVERTER", DCsheets_data)
        DCbus = PowerFlow.extract_dcdata("DCBUS", DCsheets_data)
        DC_impedance = PowerFlow.extract_dcdata("DCIMPEDANCE", DCsheets_data)
        DC_cable = PowerFlow.extract_dcdata("DCCABLE", DCsheets_data)
        Battery = PowerFlow.extract_dcdata("BATTERY", DCsheets_data)
        DC_lumpedload = PowerFlow.extract_dcdata("DCLUMPLOAD", DCsheets_data)
    else
        Inverter_data = DataFrame()
        DCbus = DataFrame()
        DC_impedance = DataFrame()
        DC_cable = DataFrame()
        Battery = DataFrame()
        DC_lumpedload = DataFrame()
    end

    #元件验证
    PowerFlow.validate_element(bus_data, gen_data, cable_data, transline_data, transformer_data, Load_data, Utility_data, HVCB_data, impedance_data, Inverter_data, DCbus, DC_impedance, DC_cable, Battery, DC_lumpedload)

    # 获取 IEEE 格式索引
    (PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, AREA, VM, VA, BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN) = PowerFlow.idx_bus()
    (FBUS, TBUS, R, X, B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, 
    BR_STATUS, ANGMIN, ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF,
     MU_ST, MU_ANGMIN, MU_ANGMAX) = PowerFlow.idx_brch()
    (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN) = PowerFlow.idx_gen()
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=PowerFlow.idx_ld()

     #处理逆变器数据
     if !isempty(DCsheets_data)
        (Ci, Cr, P_inv, Q_inv, Smax_inv, Pmax_inv, Qmax_inv, P_inv_dc, 
         PV_generation_curve1, PV_generation_curve2, PV_absorption_curve1, 
         PV_absorption_curve2) = PowerFlow.process_inverter_data(Inverter_data)
    else
        # 初始化为空向量
        Ci = Cr = Vector{Float64}()
        P_inv = Q_inv = Vector{Float64}()
        Smax_inv = Pmax_inv = Qmax_inv = P_inv_dc = Vector{Float64}()
        PV_generation_curve1 = PV_generation_curve2 = nothing
        PV_absorption_curve1 = PV_absorption_curve2 = nothing
    end

    # 处理母线和支路数据
    bus, dict_bus = PowerFlow.assign_bus_data(
        bus_data, Load_data, gen_data, Utility_data
    )

    #处理负荷数据
    load, bus = PowerFlow.process_load_data(Load_data, bus, dict_bus,Ci,P_inv,Q_inv)

    branch, HVCB_data = PowerFlow.process_branches_data(
        cable_data, transline_data, impedance_data, transformer_data,
        HVCB_data, bus, baseMVA, baseKV, dict_bus
    )

    #处理发电机数据
    gen = PowerFlow.initialize_generator_matrix(gen_data, dict_bus, bus)
    gen_utility = PowerFlow.initialize_utility_generator_matrix(Utility_data, dict_bus)
    gen = PowerFlow.combine_generator_matrices(gen, gen_utility)

    # 处理 DC 系统数据
    if !isempty(DCsheets_data)
        busdc,dcload, Dict_busdc, battery_branches, battery_gen = PowerFlow.assign_dcbus_data(
            DCbus, DC_lumpedload, Battery, Cr, P_inv_dc, baseMVA
        )
        dcbranch = PowerFlow.process_dcbranch_data(
            DC_impedance, DC_cable, battery_branches, DCbus,
            Dict_busdc, baseMVA
        )
    end

    # 处理网络拓扑
    # 打印处理前的网络统计信息
    PowerFlow.print_network_stats(bus, branch, HVCB_data)

    # 处理孤岛
    bus, branch, HVCB_data, load = PowerFlow.process_islands_by_source(bus, branch, HVCB_data,load)

    # 打印处理后的网络统计信息
    PowerFlow.print_network_stats(bus, branch, HVCB_data)

    # # 处理断路器
    # hvcb=PowerFlow.process_HVCB_data(HVCB_data)

    #对jpc结构的branch进行处理
    # branch=PowerFlow.process_branches_data_jpc(branch,hvcb)

    #负荷处理
    bus, HVCB_data, load = PowerFlow.process_load_cb_connections(
        branch, bus, gen,load, HVCB_data, PD, QD,
        FBUS, TBUS, BUS_I, TYPE, GEN_BUS,LOAD_CND,
        HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
        HVCB_STATUS, HVCB_ID
    )

    branch, bus, HVCB_data = PowerFlow.process_common_cb_connections!(
        branch, bus, gen, HVCB_data,
        FBUS, TBUS, BUS_I,TYPE, GEN_BUS,
        HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
        HVCB_STATUS, HVCB_ID
    )

    branch, bus, HVCB_data = PowerFlow.process_all_cb_connections!(
        branch, bus, gen, HVCB_data,
        FBUS, TBUS, BUS_I, TYPE, GEN_BUS,
        HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
        HVCB_STATUS, HVCB_ID
    )

    branch, bus, HVCB_data = PowerFlow.process_single_cb_connections!(
        branch, bus, gen, HVCB_data,
        FBUS, TBUS, BUS_I, TYPE, GEN_BUS,
        HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
        HVCB_STATUS, HVCB_ID
    )

    # 处理网络结构
    bus = PowerFlow.remove_isolated_buses!(branch, bus, FBUS, TBUS, BUS_I)
    branch, bus, node_mapping = PowerFlow.renumber_buses!(branch, bus, FBUS, TBUS, BUS_I)
    branch = PowerFlow.merge_parallel_branches!(branch, FBUS, TBUS, R, X, B)

    # # 更新发电机数据
    gen = update_generator_bus(gen, node_mapping)
    # # 更新负荷数据
    load = update_load_bus(load, node_mapping)

     # 构建输出
    if isempty(DCsheets_data)
        mpc = Dict(
            "baseMVA" => baseMVA,
            "gen" => gen,
            "branch" => branch,
            "load" => load,
            "bus" => bus,
            # "hvcb"=> hvcb,
            "version" => "1"
        )
        # 对于纯 AC 系统，返回空的 PV 曲线
        pv_curves = PVCurves()
    else
        mpc = Dict(
            "baseMVA" => baseMVA,
            "genAC" => gen,
            "genDC" => battery_gen,
            "branchAC" => branch,
            "branchDC" => dcbranch,
            "busAC" => bus,
            "busDC" => busdc,
            "loadAC" => load,
            "loadDC" => dcload,
            "version" => "1"
        )
        # 对于 AC/DC 混合系统，返回实际的 PV 曲线函数
        pv_curves = PVCurves(
            PV_generation_curve1,
            PV_generation_curve2,
            PV_absorption_curve1,
            PV_absorption_curve2
        )
    end

    return mpc, dict_bus, node_mapping, pv_curves
end
