function process_branches_data(cable_data::DataFrame, transline_data::DataFrame, impedance_data::DataFrame, transformer_data::DataFrame, HVCB_data::DataFrame, bus::Matrix{Float64}, baseMVA::Float64, baseKV::Float64, dict_bus)
    # --- Call indexing for IEEE branch data ---
    (FBUS, TBUS, R, X, B, RATEA, RATEB, RATEC, RATIO, ANGLE, STATUS, ANGMIN,
     ANGMAX, DICTKEY, PF, QF, PT, QT, MU_SF, MU_ST, MU_ANGMIN, MU_ANGMAX, LAMBDA, SW_TIME, RP_TIME, BR_TYPE, BR_AREA) = idx_brch()
     (PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM,VA, 
     BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN, PER_CONSUMER) = idx_bus();
    (Cable_EquipeID,Cable_inservice,Cable_Felement,Cable_Telement,Cable_length,Cable_r1,Cable_x1,Cable_y1,Cable_perunit_length_value)=PowerFlow.cable_idx()#线缆索引
    (Line_EquipmentID,Line_length,Line_inservice,Line_Felement,Line_Telement,Line_r11,Line_x1,Line_y1)=PowerFlow.xline_idx()#传输线索引
    (Trans_EquipmentID,Trans_inservice,Trans_Pelement,Trans_Selement,prisecrated_Power,Trans_Pvoltage,Trans_Svoltage,Trans_Pos_value,Trans_Pos_XRrating)=PowerFlow.XFORM2W_idx()#变压器索引
    (HVCB_ID,HVCB_FROM_ELEMENT,HVCB_TO_ELEMENT,HVCB_INSERVICE,HVCB_STATUS)=PowerFlow.hvcb_idx()#HVCB索引
    (imp_ID,imp_inservice,imp_Felement,imp_Telement,imp_R,imp_X)=PowerFlow.imp_idx()#阻抗索引
    

   # --- Clean data by removing extra branches ---
    # For cable
    cable = filter(row -> row[Cable_Felement] !== missing, cable_data)
    cable = filter(row -> row[Cable_Telement] !== missing, cable_data)

    # For transmission lines
    transline = filter(row -> row[Line_Felement] !== missing, transline_data)
    transline = filter(row -> row[Line_Telement] !== missing, transline_data)

    #For impedance
    impedance = filter(row -> row[imp_Felement] !== missing, impedance_data)
    impedance = filter(row -> row[imp_Telement] !== missing, impedance_data)

    # For transformers
    transformer = filter(row -> row[Trans_Pelement] !== missing, transformer_data)
    transformer = filter(row -> row[Trans_Selement] !== missing, transformer_data)

    # --- Initialize matrices ---
    branch_cable = zeros(size(cable, 1), 14)
    branch_transline = zeros(size(transline, 1), 14)
    branch_impedance = zeros(size(impedance, 1), 14)
    branch_transformer = zeros(size(transformer, 1), 14)
    # --- Transfer data ---
    branch_cable[:,STATUS] = (cable[:, Cable_inservice] .== "Yes").+0
    branch_transline[:,STATUS] = (transline[:, Line_inservice] .== "Yes").+0
    branch_impedance[:,STATUS] = (impedance[:, imp_inservice] .== "Yes").+0
    branch_transformer[:,STATUS] = (transformer[:, Trans_inservice] .== "Yes").+0

    # --- Assign IDs ---
    # For cable
    branch_cable[:, FBUS] = map(k -> dict_bus[k], cable[:, Cable_Felement])
    branch_cable[:, TBUS] = map(k -> dict_bus[k], cable[:, Cable_Telement])

    # For transmission lines
    branch_transline[:, FBUS] = map(k -> dict_bus[k], transline[:, Line_Felement])
    branch_transline[:, TBUS] = map(k -> dict_bus[k], transline[:, Line_Telement])

    # For impedance
    branch_impedance[:, FBUS] = map(k -> dict_bus[k], impedance[:, imp_Felement])
    branch_impedance[:, TBUS] = map(k -> dict_bus[k], impedance[:, imp_Telement])

    # For transformers
    branch_transformer[:, FBUS] = map(k -> dict_bus[k], transformer[:, Trans_Pelement])
    branch_transformer[:, TBUS] = map(k -> dict_bus[k], transformer[:, Trans_Selement])

    # --- Assign R, X, B for each branch type ---
    # For cable
    branch_cable[:, R] = cable[:, Cable_length] .* cable[:, Cable_r1] ./ cable[:, Cable_perunit_length_value]
    branch_cable[:, X] = cable[:, Cable_length] .* cable[:, Cable_x1] ./ cable[:, Cable_perunit_length_value]
    branch_cable[:, B] = cable[:, Cable_length] .* cable[:, Cable_y1] ./ cable[:, Cable_perunit_length_value]

    # For transmission lines
    branch_transline[:, R] = transline[:, Line_length] .* parse.(Float64, transline[:, Line_r11]) .* 0.000621371
    branch_transline[:, X] = transline[:, Line_length] .* parse.(Float64, transline[:, Line_x1]) .* 0.000621371
    branch_transline[:, B] = transline[:, Line_length] .* parse.(Float64, transline[:, Line_y1]) .* 0.000621371

    # For impedance
    branch_impedance[:, R] = impedance[:, imp_R]./100
    branch_impedance[:, X] = impedance[:, imp_X]./100

    # For transformers
    Zbase = baseKV^2 / baseMVA
    branch_transformer[:, R] = 0.01 .* transformer[:, Trans_Pos_value] .* transformer[:, Trans_Pvoltage].^2 .* inv.(transformer[:, prisecrated_Power]) .* inv.(sqrt.(1 .+ transformer[:, Trans_Pos_XRrating].^2)) ./ Zbase
    branch_transformer[:, X] = branch_transformer[:, R] .* transformer[:, Trans_Pos_XRrating]
    branch_transformer[:, B] .= 0

    # --- Assign Rate and Status ---
    rate_values = 100  # MVA
    for branch in [branch_cable, branch_transline, branch_impedance, branch_transformer]
        branch[:, RATEA] .= rate_values
        branch[:, RATEB] .= rate_values
        branch[:, RATEC] .= rate_values
        branch[:, RATIO] .= 0
        branch[:, ANGLE] .= 0
        branch[:, ANGMIN] .= -180
        branch[:, ANGMAX] .= 180
    end

    for branch in[branch_cable, branch_transline, branch_impedance]
        branch[:, RATIO] .= 1.0
    end
    # --- Normalize impedance to per unit ---
    # Normalize for cables
    cable_basekv = bus[Int.(branch_cable[:, FBUS]), BASEKV]
    branch_cable[:, R] .= branch_cable[:, R] .* baseMVA .* inv.(cable_basekv.^2)
    branch_cable[:, X] .= branch_cable[:, X] .* baseMVA .* inv.(cable_basekv.^2)
    branch_cable[:, B] .= branch_cable[:, B] .* baseMVA .* inv.(cable_basekv.^2)

    # Normalize for transmission lines
    trans_basekv = bus[Int.(branch_transline[:, FBUS]), BASEKV]
    branch_transline[:, R] .= branch_transline[:, R] .* baseMVA .* inv.(trans_basekv.^2)
    branch_transline[:, X] .= branch_transline[:, X] .* baseMVA .* inv.(trans_basekv.^2)
    branch_transline[:, B] .= branch_transline[:, B] .* baseMVA .* inv.(trans_basekv.^2)

    # Normalize for transformers
    transformer_basekv = transformer[:, Trans_Pvoltage]
    branch_transformer[:, R] .= branch_transformer[:, R] .* baseMVA .* inv.(transformer_basekv.^2)
    branch_transformer[:, X] .= branch_transformer[:, X] .* baseMVA .* inv.(transformer_basekv.^2)
    branch_transformer[:, B] .= branch_transformer[:, B] .* baseMVA .* inv.(transformer_basekv.^2)

    # --- Combine all branches ---
    branch = [branch_cable; branch_transline; branch_impedance; branch_transformer]

    # --- Topology reconstruction ---
    # Update HVCB data
    HVCB_data = filter(row -> row[HVCB_FROM_ELEMENT] !== missing, HVCB_data)
    HVCB_data = filter(row -> row[HVCB_TO_ELEMENT] !== missing, HVCB_data)

    #Construct a hvcb matrix
    hvcb=zeros(size(HVCB_data,1),5)
    hvcb[:,]
    HVCB_data = HVCB_data[findall(HVCB_data[:, HVCB_INSERVICE] .== "Yes"), :]
    HVCB_data = HVCB_data[.!ismissing.(HVCB_data[:, HVCB_FROM_ELEMENT]), :]
    HVCB_data = HVCB_data[.!ismissing.(HVCB_data[:, HVCB_TO_ELEMENT]), :]
    HVCB_data[:, HVCB_FROM_ELEMENT] = map(k -> dict_bus[k], HVCB_data[:, HVCB_FROM_ELEMENT])
    HVCB_data[:, HVCB_TO_ELEMENT] = map(k -> dict_bus[k], HVCB_data[:, HVCB_TO_ELEMENT])

    return branch, HVCB_data
end