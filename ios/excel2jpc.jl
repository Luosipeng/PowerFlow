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
    excel2jpc(file_path)

将 Excel 格式的电力系统数据转换为 IEEE 格式。
支持纯AC系统、纯DC系统或AC/DC混合系统。

返回值：
- mpc: 包含系统数据的字典
- dict_bus: AC母线映射字典（仅当AC系统存在时）
- node_mapping: AC节点映射（仅当AC系统存在时）
- pv_curves: PV曲线数据结构（包含函数方法）
- Dict_busdc: DC母线映射字典（仅当DC系统存在时）
"""
function excel2jpc(file_path)
    # 系统基准值
    baseMVA = 100.0
    baseKV = 10.0

    # 读取系统数据（AC 和 DC 数据都从同一个文件中读取）
    sheets_data = Dict{String, DataFrame}()
    XLSX.openxlsx(file_path) do wb
        for sheet_name in XLSX.sheetnames(wb)
            sheet = XLSX.getsheet(wb, sheet_name)
            sheets_data[sheet_name] = DataFrame(sheet[:], :auto)
        end
    end

    # 获取 HVCB 索引
    (HVCB_ID, HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT, HVCB_INSERVICE, HVCB_STATUS) = PowerFlow.hvcb_idx()

    # 提取 AC 系统组件数据
    bus_data = PowerFlow.extract_data("BUS", sheets_data)
    gen_data = PowerFlow.extract_data("SYNGEN", sheets_data)
    cable_data = PowerFlow.extract_data("ACCABLE", sheets_data)
    transline_data = PowerFlow.extract_data("XLINE", sheets_data)
    transformer_data = PowerFlow.extract_data("XFORM2W", sheets_data)
    Load_data = PowerFlow.extract_data("LUMPEDLOAD", sheets_data)
    Utility_data = PowerFlow.extract_data("UTIL", sheets_data)
    HVCB_data = PowerFlow.extract_data("HVCB", sheets_data)
    impedance_data = PowerFlow.extract_data("IMPEDANCE", sheets_data)

    # 提取 DC 系统组件数据
    Inverter_data = PowerFlow.extract_data("INVERTER", sheets_data)
    Charger_data = PowerFlow.extract_data("CHARGER", sheets_data)
    DCbus = PowerFlow.extract_data("DCBUS", sheets_data)
    DC_impedance = PowerFlow.extract_data("DCIMPEDANCE", sheets_data)
    DC_cable = PowerFlow.extract_data("DCCABLE", sheets_data)
    Battery = PowerFlow.extract_data("BATTERY", sheets_data)
    DC_lumpedload = PowerFlow.extract_data("DCLUMPLOAD", sheets_data)

    # 检查是否存在 AC 和 DC 系统数据
    has_ac_system = !isempty(bus_data)
    has_dc_system = !isempty(DCbus)

    # 获取 IEEE 格式索引
    (PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, AREA, VM, VA, BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN) = PowerFlow.idx_bus()
    (FBUS, TBUS, R, X, B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, 
    BR_STATUS, ANGMIN, ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF,
     MU_ST, MU_ANGMIN, MU_ANGMAX) = PowerFlow.idx_brch()
    (GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN) = PowerFlow.idx_gen()
    (LOAD_I,LOAD_CND,LOAD_STATUS,LOAD_PD,LOAD_QD,LOADZ_PERCENT,LOADI_PERCENT,LOADP_PERCENT)=PowerFlow.idx_ld()

    # 初始化 PV 曲线变量
    PV_generation_curve1 = PV_generation_curve2 = nothing
    PV_absorption_curve1 = PV_absorption_curve2 = nothing
    
    # 处理逆变器数据
    if !isempty(Inverter_data)
        (Ci, Cr, P_inv, Q_inv, Smax_inv, Pmax_inv, Qmax_inv, P_inv_dc, 
         PV_generation_curve1, PV_generation_curve2, PV_absorption_curve1, 
         PV_absorption_curve2) = PowerFlow.process_inverter_data(Inverter_data)
    else
        # 初始化为空向量
        Ci = Cr = Vector{Float64}()
        P_inv = Q_inv = Vector{Float64}()
        Smax_inv = Pmax_inv = Qmax_inv = P_inv_dc = Vector{Float64}()
    end

    # 初始化 AC 系统变量
    bus = branch = gen = load = dict_bus = node_mapping = nothing
    
    # 处理 AC 系统数据（如果存在）
    if has_ac_system
        # 处理母线和支路数据
        bus, dict_bus = PowerFlow.assign_bus_data(
            bus_data, Load_data, gen_data, Utility_data
        )

        # 处理负荷数据
        load, bus = PowerFlow.process_load_data(Load_data, bus, dict_bus, Ci, P_inv, Q_inv)

        branch, HVCB_data = PowerFlow.process_branches_data(
            cable_data, transline_data, impedance_data, transformer_data,
            HVCB_data, bus, baseMVA, baseKV, dict_bus
        )

        # 处理发电机数据
        gen = PowerFlow.initialize_generator_matrix(gen_data, dict_bus, bus)
        gen_utility = PowerFlow.initialize_utility_generator_matrix(Utility_data, dict_bus)
        gen = PowerFlow.combine_generator_matrices(gen, gen_utility)
        
        # 处理网络拓扑
        # 打印处理前的网络统计信息
        PowerFlow.print_network_stats(bus, branch, HVCB_data)

        # 处理孤岛
        bus, branch, HVCB_data, load = PowerFlow.process_islands_by_source(bus, branch, HVCB_data, load)

        # 打印处理后的网络统计信息
        PowerFlow.print_network_stats(bus, branch, HVCB_data)

        # 负荷处理
        bus, HVCB_data, load = PowerFlow.process_load_cb_connections(
            branch, bus, gen, load, HVCB_data, PD, QD,
            FBUS, TBUS, BUS_I, TYPE, GEN_BUS, LOAD_CND,
            HVCB_FROM_ELEMENT, HVCB_TO_ELEMENT,
            HVCB_STATUS, HVCB_ID
        )

        branch, bus, HVCB_data = PowerFlow.process_common_cb_connections!(
            branch, bus, gen, HVCB_data,
            FBUS, TBUS, BUS_I, TYPE, GEN_BUS,
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

        # 更新发电机数据
        gen = PowerFlow.update_generator_bus(gen, node_mapping)
        # 更新负荷数据
        load = PowerFlow.update_load_bus(load, node_mapping)
    end

    # 初始化 DC 系统变量
    busdc = dcload = Dict_busdc = battery_branches = battery_gen = dcbranch = nothing

    # 处理 DC 系统数据（如果存在）
    if has_dc_system
        busdc, dcload, Dict_busdc, battery_branches, battery_gen = PowerFlow.assign_dcbus_data(
            DCbus, DC_lumpedload, Battery, Cr, P_inv_dc, baseMVA
        )
        
        dcbranch = PowerFlow.process_dcbranch_data(
            DC_impedance, DC_cable, battery_branches, DCbus,
            Dict_busdc, baseMVA
        )
        
        # 只有当AC系统和充电器数据都存在时才处理充电器
        if has_ac_system && !isempty(Charger_data)
            gen, bus, busdc, battery_gen = PowerFlow.process_charger_data(
                Charger_data, gen, dict_bus, Dict_busdc, busdc, bus
            )
        end
    end

    # 构建 PV 曲线结构
    pv_curves = PVCurves(
        PV_generation_curve1,
        PV_generation_curve2,
        PV_absorption_curve1,
        PV_absorption_curve2
    )

    # 根据系统类型构建输出
    if has_ac_system && has_dc_system
        # AC/DC 混合系统
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
        return mpc, dict_bus, node_mapping, pv_curves, Dict_busdc
    elseif has_ac_system
        # 纯 AC 系统
        mpc = Dict(
            "baseMVA" => baseMVA,
            "gen" => gen,
            "branch" => branch,
            "load" => load,
            "bus" => bus,
            "version" => "1"
        )
        return mpc, dict_bus, node_mapping, pv_curves
    elseif has_dc_system
        # 纯 DC 系统
        mpc = Dict(
            "baseMVA" => baseMVA,
            "gen" => battery_gen,
            "branch" => dcbranch,
            "bus" => busdc,
            "load" => dcload,
            "version" => "1"
        )
        return mpc, Dict_busdc, pv_curves
    else
        # 没有任何系统数据
        error("No AC or DC system data found in the input file.")
    end
end
