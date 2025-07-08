"""
    resolve_node_mapping(node_id, node_merge_map)

Recursively resolve node mapping, ensuring multi-level merges are correctly processed.
"""
function resolve_node_mapping(node_id, node_merge_map)
    while haskey(node_merge_map, node_id)
        node_id = node_merge_map[node_id]
    end
    return node_id
end

"""
    merge_virtual_nodes(case::JuliaPowerCase)

Merge nodes on both sides of virtual nodes, remove virtual nodes and virtual connections,
to avoid singular admittance matrix in power flow calculations.
Returns updated case object without virtual nodes and virtual connections.
"""
function merge_virtual_nodes(case::JuliaPowerCase)
    # Deep copy case for modification
    new_case = deepcopy(case)
    
    # Identify virtual nodes (nodes with names containing "_virtual_node")
    virtual_node_ids = Int[]
    virtual_node_map = Dict{Int, String}()  # Mapping from virtual node ID to name
    
    for bus in new_case.busesAC
        if occursin("_virtual_node", bus.name)
            push!(virtual_node_ids, bus.bus_id)
            virtual_node_map[bus.bus_id] = bus.name
        end
    end
    
    # If no virtual nodes, return original case
    if isempty(virtual_node_ids)
        return new_case
    end
    
    # Identify circuit breakers and actual nodes connected to virtual nodes
    virtual_connections = Dict{Int, Vector{Tuple{Int, Int}}}()  # Virtual node ID -> [(Connected node ID, Circuit breaker index)]
    
    for (i, hvcb) in enumerate(new_case.hvcbs)
        if !hvcb.closed || !hvcb.in_service
            continue
        end
        
        # Check if circuit breaker is connected to a virtual node
        if hvcb.bus_from in virtual_node_ids
            if !haskey(virtual_connections, hvcb.bus_from)
                virtual_connections[hvcb.bus_from] = Tuple{Int, Int}[]
            end
            push!(virtual_connections[hvcb.bus_from], (hvcb.bus_to, i))
        elseif hvcb.bus_to in virtual_node_ids
            if !haskey(virtual_connections, hvcb.bus_to)
                virtual_connections[hvcb.bus_to] = Tuple{Int, Int}[]
            end
            push!(virtual_connections[hvcb.bus_to], (hvcb.bus_from, i))
        end
    end
    
    # For each virtual node, determine merge strategy
    node_merge_map = Dict{Int, Int}()  # Original node ID -> Merged node ID
    
    # Step 1: Process each virtual node, initially determine merge mapping
    for virtual_node_id in virtual_node_ids
        if !haskey(virtual_connections, virtual_node_id) || length(virtual_connections[virtual_node_id]) < 2
            # Virtual node needs to connect to at least two other nodes for merging
            continue
        end
        
        # Get all actual nodes connected to the virtual node
        connected_nodes = [node_id for (node_id, _) in virtual_connections[virtual_node_id]]
        
        # Choose the first node as the target node for merging
        target_node_id = connected_nodes[1]
        
        # Map other nodes to the target node
        for node_id in connected_nodes[2:end]
            # Check if there's already a mapping, if so, ensure consistency
            if haskey(node_merge_map, node_id)
                # Already has mapping, need to map current target node to the same node
                existing_target = resolve_node_mapping(node_id, node_merge_map)
                node_merge_map[target_node_id] = existing_target
                target_node_id = existing_target
            else
                node_merge_map[node_id] = target_node_id
            end
        end
        
        # Also map the virtual node to the target node
        node_merge_map[virtual_node_id] = target_node_id
    end
    
    # Step 2: Resolve all mappings to ensure consistency
    for node_id in keys(node_merge_map)
        node_merge_map[node_id] = resolve_node_mapping(node_merge_map[node_id], node_merge_map)
    end
    
    # Update node references in all elements
    
    # 1. Update AC lines
    for line in new_case.branchesAC
        if !line.in_service
            continue
        end
        
        line.from_bus = resolve_node_mapping(line.from_bus, node_merge_map)
        line.to_bus = resolve_node_mapping(line.to_bus, node_merge_map)
        
        # Check if a self-loop is formed (same node connected to itself)
        if line.from_bus == line.to_bus
            line.in_service = false  # Disable self-loop
        end
    end
    
    # 2. Update transformers
    for transformer in new_case.transformers_2w_etap
        if !transformer.in_service
            continue
        end
        
        transformer.hv_bus = resolve_node_mapping(transformer.hv_bus, node_merge_map)
        transformer.lv_bus = resolve_node_mapping(transformer.lv_bus, node_merge_map)
        
        # Check if a self-loop is formed
        if transformer.hv_bus == transformer.lv_bus
            transformer.in_service = false  # Disable self-loop
        end
    end
    
    # 3. Update circuit breakers
    new_hvcbs = []
    for hvcb in new_case.hvcbs
        if !hvcb.closed || !hvcb.in_service
            push!(new_hvcbs, hvcb)
            continue
        end
        
        # Resolve node mappings
        new_from = resolve_node_mapping(hvcb.bus_from, node_merge_map)
        new_to = resolve_node_mapping(hvcb.bus_to, node_merge_map)
        
        # If circuit breaker doesn't form a self-loop and doesn't connect to a virtual node that will be removed, keep it
        if new_from != new_to && !(hvcb.bus_from in virtual_node_ids || hvcb.bus_to in virtual_node_ids)
            hvcb.bus_from = new_from
            hvcb.bus_to = new_to
            push!(new_hvcbs, hvcb)
        end
    end
    new_case.hvcbs = new_hvcbs
    
    # 4. Update loads
    for load in new_case.loadsAC
        if !load.in_service
            continue
        end
        
        load.bus = resolve_node_mapping(load.bus, node_merge_map)
    end
    
    # 5. Update generators
    for gen in new_case.sgensAC
        if !gen.in_service
            continue
        end
        
        gen.bus = resolve_node_mapping(gen.bus, node_merge_map)
    end
    
    # 6. Update external grids
    for ext in new_case.ext_grids
        if !ext.in_service
            continue
        end
        
        ext.bus = resolve_node_mapping(ext.bus, node_merge_map)
    end
    
    # Remove virtual nodes
    new_busesAC = []
    for bus in new_case.busesAC
        if !(bus.bus_id in virtual_node_ids)
            push!(new_busesAC, bus)
        end
    end
    new_case.busesAC = new_busesAC
    
    # Update node name to ID mapping
    new_case.bus_name_to_id = Dict{String, Int}()
    for bus in new_case.busesAC
        new_case.bus_name_to_id[bus.name] = bus.bus_id
    end
    
    # Merge loads on the same node
    load_by_bus = Dict{Int, Vector{Int}}()  # Node ID -> List of load indices
    
    for (i, load) in enumerate(new_case.loadsAC)
        if !load.in_service
            continue
        end
        
        if !haskey(load_by_bus, load.bus)
            load_by_bus[load.bus] = Int[]
        end
        push!(load_by_bus[load.bus], i)
    end
    
    # For each node with multiple loads, merge the loads
    new_loadsAC = []
    processed_loads = Set{Int}()
    
    for (bus_id, load_indices) in load_by_bus
        if length(load_indices) <= 1
            # Only one load, keep it as is
            for idx in load_indices
                push!(new_loadsAC, new_case.loadsAC[idx])
                push!(processed_loads, idx)
            end
        else
            # Multiple loads, merge them
            total_p_mw = 0.0
            total_q_mvar = 0.0
            base_load = nothing
            
            for idx in load_indices
                load = new_case.loadsAC[idx]
                total_p_mw += load.p_mw
                total_q_mvar += load.q_mvar
                
                if base_load === nothing
                    base_load = deepcopy(load)
                end
                
                push!(processed_loads, idx)
            end
            
            # Use the first load as a base, update active and reactive power
            if base_load !== nothing
                base_load.p_mw = total_p_mw
                base_load.q_mvar = total_q_mvar
                base_load.name = "Merged_Load_$(bus_id)"
                push!(new_loadsAC, base_load)
            end
        end
    end
    
    # Add unprocessed loads (e.g., disabled loads)
    for (i, load) in enumerate(new_case.loadsAC)
        if i ∉ processed_loads && !load.in_service
            push!(new_loadsAC, load)
        end
    end
    
    new_case.loadsAC = new_loadsAC
    
    # Similarly, other elements connected to the same node could be merged (such as generators, shunt elements, etc.)
    # ...
    
    return new_case
end

function JuliaPowerCase2Jpc(case::Utils.JuliaPowerCase)
    # 1. Merge virtual nodes
    case = merge_virtual_nodes(case)
    
    # 2. Create JPC object
    jpc = JPC()
    
    # 3. Set basic parameters
    jpc.baseMVA = case.baseMVA
    
    # 4. Set node data
    JPC_buses_process(case, jpc)

    # 5. Set DC node data
    JPC_dcbuses_process(case, jpc)
    
    # 6. Set line data
    JPC_branches_process(case, jpc)
    
    # 7. Set DC line data
    JPC_dcbranches_process(case, jpc)

    # 8. Set generator data
    JPC_gens_process(case, jpc)

    # 9. Set DC generator data
    JPC_battery_gens_process(case, jpc)

    # 10. Set battery SOC data
    JPC_battery_soc_process(case, jpc)
    
    # 11. Set load data
    JPC_loads_process(case, jpc)

    # 12. Set DC load data
    JPC_dcloads_process(case, jpc)

    # 13. Set PV array data 
    JPC_pv_process(case, jpc)

    # 14. Set converter data
    JPC_inverters_process(case, jpc)

    # 15. Set AC PV system data
    JPC_ac_pv_system_process(case, jpc)

    return jpc
end

function JPC_buses_process(case::JuliaPowerCase, jpc::JPC)
    # Get node data and deep copy to prevent unintended operations
    buses = deepcopy(case.busesAC)
    
    # Create an empty matrix with rows equal to number of nodes and 13 columns
    num_buses = length(buses)
    bus_matrix = zeros(num_buses, 13)
    
    for (i, bus) in enumerate(buses)
        # Set initial voltage values (based on index)
        vm = 1.0
        va = 0.0
        
        # Fill each row of the matrix
        bus_matrix[i, :] = [
            bus.bus_id,      # Node ID
            1.0,             # Node type (all set to PQ nodes)
            0.0,             # PD (MW) Active load (MW)
            0.0,             # QD (MVAR) Reactive load (MVAR)
            0.0,             # GS (MW) Active generation (MW)
            0.0,             # BS (MVAR) Reactive generation (MVAR)
            bus.area_id,     # Area number
            vm,              # Node voltage magnitude (p.u.)
            va,              # Node voltage angle (degrees)
            bus.vn_kv,       # Node voltage base (kV)
            bus.zone_id,     # Zone number
            bus.max_vm_pu,   # Maximum voltage magnitude (p.u.)
            bus.min_vm_pu,   # Minimum voltage magnitude (p.u.)
        ]
    end
    
    # Store all results in busAC field
    jpc.busAC = bus_matrix
    
    return jpc
end

function JPC_dcbuses_process(case, jpc)
    # Process DC node data, convert to JPC format
    dcbuses = deepcopy(case.busesDC)
    
    # Create an empty matrix with rows equal to number of nodes and 13 columns
    num_dcbuses = length(dcbuses)
    dcbus_matrix = zeros(num_dcbuses, 13)
    
    for (i, dcbus) in enumerate(dcbuses)
        # Set initial voltage values (based on index)
        vm = 1.0
        va = 0.0
        
        # Fill each row of the matrix
        dcbus_matrix[i, :] = [
            dcbus.bus_id,      # Node ID
            1.0,               # Node type (all set to PQ nodes)
            0.0,               # PD (MW) Active load (MW)
            0.0,               # QD (MVAR) Reactive load (MVAR)
            0.0,               # GS (MW) Active generation (MW)
            0.0,               # BS (MVAR) Reactive generation (MVAR)
            dcbus.area_id,     # Area number
            vm,                # Node voltage magnitude (p.u.)
            va,                # Node voltage angle (degrees)
            dcbus.vn_kv,       # Node voltage base (kV)
            dcbus.zone_id,     # Zone number
            dcbus.max_vm_pu,   # Maximum voltage magnitude (p.u.)
            dcbus.min_vm_pu,   # Minimum voltage magnitude (p.u.)
        ]
    end
    
    # Store all results in busDC field
    jpc.busDC = dcbus_matrix

    jpc = JPC_battery_bus_process(case, jpc)
    
    return jpc
end

function JPC_battery_bus_process(case::JuliaPowerCase, jpc::JPC)
    # Process battery node data, convert to JPC format and merge into busDC
    batteries = deepcopy(case.storageetap)
    
    # Get current busDC data
    busDC = jpc.busDC
    current_size = size(busDC, 1)
    
    # Create a matrix to store battery node data
    num_batteries = length(batteries)
    battery_matrix = zeros(num_batteries, size(busDC, 2))
    
    for (i, battery) in enumerate(batteries)
        # Set initial voltage values
        vm = 1.0
        va = 0.0
        vn_kv = battery.voc
        # Create virtual node data
        battery_row = zeros(1, size(busDC, 2))
        battery_row[1, :] = [
            current_size + i,    # Assign new node ID for battery
            2.0,                 # Node type (all set to slack nodes)
            0.0,                 # PD (MW) Active load (MW)
            0.0,                 # QD (MVAR) Reactive load (MVAR)
            0.0,                 # GS (MW) Active generation (MW)
            0.0,                 # BS (MVAR) Reactive generation (MVAR)
            1.0,                 # Area number
            vm,                  # Node voltage magnitude (p.u.)
            va,                  # Node voltage angle (degrees)
            vn_kv,               # Node voltage base (kV)
            1.0,                 # Zone number
            1.05,                # Maximum voltage magnitude (p.u.)
            0.95                 # Minimum voltage magnitude (p.u.)
        ]
        
        # Store battery node data in matrix
        battery_matrix[i, :] = battery_row
    end
    
    # Merge battery virtual nodes into busDC
    jpc.busDC = vcat(busDC, battery_matrix)
    
    # # Also save original battery data to jpc.battery field for later processing
    # jpc.battery = battery_matrix

    return jpc
end

function JPC_branches_process(case::JuliaPowerCase, jpc::JPC)
    # if sequence == 1||sequence == 2
        # Process line data, convert to JPC format
        calculate_line_parameters(case::JuliaPowerCase, jpc)
        # Process transformer data, convert to JPC format
        calculate_transformer2w_parameters(case::JuliaPowerCase, jpc)
        # Process three-phase transformer data, convert to JPC format
    # else
    #     # Process branch data, convert to JPC format
    #     calculate_branch_JPC_zero(case::JuliaPowerCase, jpc)
    # end
end

function JPC_dcbranches_process(case::JuliaPowerCase, jpc::JPC)
    # Process DC line data, convert to JPC format
    nbr = length(case.branchesDC)
    branch = zeros(nbr, 14)
    dclines = case.branchesDC

    for (i, dcline) in enumerate(dclines)
        # Get from and to bus numbers
        from_bus_idx = dcline.from_bus
        to_bus_idx = dcline.to_bus
        
        # Get base voltage of from bus (kV)
        basekv = jpc.busDC[from_bus_idx, BASE_KV]
        
        # Calculate base impedance
        baseR = (basekv^2) / case.baseMVA
        
        # Calculate per unit impedance
        r_pu = 2 * dcline.length_km * dcline.r_ohm_per_km / baseR
        x_pu = 0
        
        # Fill branchAC matrix
        branch[i, F_BUS] = from_bus_idx
        branch[i, T_BUS] = to_bus_idx
        branch[i, BR_R] = r_pu
        branch[i, BR_X] = x_pu
        
        # Set rated capacity
        if hasfield(typeof(dcline), :max_i_ka)
            branch[i, RATE_A] = dcline.max_i_ka * basekv * sqrt(3)  # Rated capacity (MVA)
        else
            branch[i, RATE_A] = 100.0  # Default value
        end
        
        # Set branch status
        branch[i, BR_STATUS] = dcline.in_service ? 1.0 : 0.0
        
        # Set angle limits
        branch[i, ANGMIN] = -360.0
        branch[i, ANGMAX] = 360.0
    end
    # Add DC line data to JPC structure
    if isempty(jpc.branchDC)
        jpc.branchDC = branch
    else
        jpc.branchDC = [jpc.branchDC; branch]
    end
    
    # Process storage virtual connections
    jpc = JPC_battery_branch_process(case, jpc)

    return jpc
end

function JPC_battery_branch_process(case::JuliaPowerCase, jpc::JPC)
    # Process battery virtual connections, create branches from battery virtual nodes to actual connection nodes
    batteries = deepcopy(case.storageetap)
    num_batteries = length(batteries)
    
    # If no batteries, return directly
    if num_batteries == 0
        return jpc
    end
    
    # Create battery virtual branch matrix, with same structure as branchDC
    battery_branches = zeros(num_batteries, 14)
    
    # Get current busDC size, used to determine virtual node numbering
    busDC_size = size(jpc.busDC, 1) - num_batteries
    
    for (i, battery) in enumerate(batteries)
        # Get actual node number that battery is connected to
        actual_bus = battery.bus
        
        # Calculate battery virtual node number (based on numbering rule in JPC_battery_process)
        virtual_bus = busDC_size + i
        
        # Get node base voltage (kV)
        basekv = 0.0
        for j in 1:size(jpc.busDC, 1)
            if jpc.busDC[j, 1] == actual_bus
                basekv = jpc.busDC[j, BASE_KV]
                break
            end
        end
        
        # Calculate base impedance
        baseR = (basekv^2) / case.baseMVA
        
        # Calculate per unit impedance (using battery internal resistance)
        # r_pu = battery.ra / baseR
        # r_pu = 0.0242/baseR  # Assume battery internal resistance is 0.0242Ω
        r_pu = 0.0252115/baseR  # Assume battery internal resistance is 0.0249Ω
        x_pu = 0  # DC system has no reactance, set to a very small value
        
        # Fill virtual branch matrix
        battery_branches[i, F_BUS] = virtual_bus       # Virtual node
        battery_branches[i, T_BUS] = actual_bus        # Actual connection node
        battery_branches[i, BR_R] = r_pu               # Per unit resistance
        battery_branches[i, BR_X] = x_pu               # Per unit reactance
        
        # Set rated capacity (calculated based on battery parameters)
        # Assume battery rated capacity can be calculated from battery parameters
        rated_capacity = battery.package * battery.voc  # Simplified calculation, actual may need more complex formula
        battery_branches[i, RATE_A] = rated_capacity
        
        # Set branch status
        battery_branches[i, BR_STATUS] = battery.in_service ? 1.0 : 0.0
        
        # Set angle limits (usually not limited in DC systems)
        battery_branches[i, ANGMIN] = -360.0
        battery_branches[i, ANGMAX] = 360.0
    end
    
    # Add battery virtual branches to branchDC
    if isempty(jpc.branchDC)
        jpc.branchDC = battery_branches
    else
        jpc.branchDC = [jpc.branchDC; battery_branches]
    end
    
    return jpc
end

function JPC_battery_soc_process(case::JuliaPowerCase, jpc::JPC)
    # Process battery SOC data, convert to JPC format
    batteries = deepcopy(case.storages)
    num_batteries = length(batteries)
    
    # If no batteries, return directly
    if num_batteries == 0
        return jpc
    end
    
    # Create battery SOC matrix
    battery_soc = zeros(num_batteries, 8)  
    
    for (i, battery) in enumerate(batteries)
        battery_soc[i, 1] = battery.bus  # Battery connected bus ID
        battery_soc[i, 2] = battery.power_capacity_mw   # Battery SOC value (per unit)
        battery_soc[i, 3] = battery.energy_capacity_mwh  # Battery active power (MW)
        battery_soc[i, 4] = battery.soc_init  # Battery reactive power (MVAR)
        battery_soc[i, 5] = battery.min_soc  # Battery maximum active power (MW)
        battery_soc[i, 6] = battery.max_soc  # Battery minimum active power (MW)
        battery_soc[i, 7] = battery.efficiency  # Battery maximum reactive power (MVAR)
        battery_soc[i, 8] = battery.in_service ? 1.0 : 0.0  # Battery in service (1.0 means in service, 0.0 means not in service)
    end
    for (i, battery) in enumerate(batteries)
        # Get actual node number that battery is connected to
        bus_id = battery.bus
        # Find corresponding node in JPC's busDC
        bus_index = findfirst(x -> x[1] == bus_id, jpc.busDC[:, 1])
        jpc.busDC[bus_index, PD] -= 0.0
        loadDC = zeros(1, 8)  # Create an empty load matrix
        nd = size(jpc.busDC, 1)
        loadDC[1, 1] = nd + 1  # Set load corresponding bus ID
        loadDC[1, 2] = bus_index
        loadDC[1, 3] = 1 # inservice
        loadDC[1, 4] = 0.0
        loadDC[1, 5] = 0.0
        loadDC[1, 6] = 0.0  
        loadDC[1, 7] = 0.0
        loadDC[1, 8] = 1.0
        # Add load data to JPC's load matrix
        if isempty(jpc.loadDC)
            jpc.loadDC = loadDC
        else
            jpc.loadDC = [jpc.loadDC; loadDC]
        end
    end
    # Add battery SOC data to JPC structure
    jpc.storage = battery_soc
    
    return jpc
end


function calculate_line_parameters(case::JuliaPowerCase, jpc::JPC)
    # Process line data, convert to JPC format
    nbr = length(case.branchesAC)
    branch = zeros(nbr, 14)
    lines = case.branchesAC

    for (i, line) in enumerate(lines)
        # Get from and to bus numbers
        from_bus_idx = line.from_bus
        to_bus_idx = line.to_bus
        
        # Get base voltage of from bus (kV)
        basekv = jpc.busAC[from_bus_idx, BASE_KV]
        
        # Calculate base impedance
        baseR = (basekv^2) / case.baseMVA
        
        # Consider parallel lines
        parallel = hasfield(typeof(line), :parallel) ? line.parallel : 1.0
        
        # Calculate per unit impedance
        r_pu = line.length_km * line.r_ohm_per_km / baseR / parallel
        x_pu = line.length_km * line.x_ohm_per_km / baseR / parallel
        
        # Calculate shunt susceptance (p.u.)
        b_pu = 2 * π * case.basef * line.length_km * line.c_nf_per_km * 1e-9 * baseR * parallel
        
        # Calculate shunt conductance (p.u.)
        g_pu = 0.0
        if hasfield(typeof(line), :g_us_per_km)
            g_pu = line.g_us_per_km * 1e-6 * baseR * line.length_km * parallel
        end
        
        # Fill branchAC matrix
        branch[i, F_BUS] = from_bus_idx
        branch[i, T_BUS] = to_bus_idx
        branch[i, BR_R] = r_pu
        branch[i, BR_X] = x_pu
        branch[i, BR_B] = b_pu
        
        # Set rated capacity
        if hasfield(typeof(line), :max_i_ka)
            branch[i, RATE_A] = line.max_i_ka * basekv * sqrt(3)  # Rated capacity (MVA)
        else
            branch[i, RATE_A] = 100.0  # Default value
        end
        
        # Set branch status
        branch[i, BR_STATUS] = line.in_service ? 1.0 : 0.0
        
        # Set angle limits
        branch[i, ANGMIN] = -360.0
        branch[i, ANGMAX] = 360.0
    end

    jpc.branchAC = branch
end

function calculate_transformer2w_parameters(case::JuliaPowerCase, jpc::JPC)
    # Process transformer data, convert to JPC format
    transformers = case.transformers_2w_etap
    nbr = length(transformers)
    
    if nbr == 0
        return  # If no transformers, return directly
    end
    
    # Create transformer branch matrix
    branch = zeros(nbr, 14)
    
    for (i, transformer) in enumerate(transformers)
        # Get high voltage and low voltage bus numbers
        hv_bus_idx = transformer.hv_bus
        lv_bus_idx = transformer.lv_bus
        
        # Get high voltage bus base voltage (kV)
        hv_basekv = jpc.busAC[hv_bus_idx, BASE_KV]
        
        # Calculate impedance parameters
        # Convert transformer impedance percentage to per unit
        z_pu = transformer.z_percent
        x_r_ratio = transformer.x_r
        
        # Calculate resistance and reactance (considering base power conversion)
        s_ratio = transformer.sn_mva / case.baseMVA
        z_pu = z_pu / s_ratio  # Convert to system base
        
        r_pu = z_pu / sqrt(1 + x_r_ratio^2)
        x_pu = r_pu * x_r_ratio
        
                # Consider parallel transformers
        parallel = transformer.parallel
        if parallel > 1
            r_pu = r_pu / parallel
            x_pu = x_pu / parallel
        end
        
        # Fill branch matrix
        branch[i, F_BUS] = hv_bus_idx
        branch[i, T_BUS] = lv_bus_idx
        branch[i, BR_R] = r_pu
        branch[i, BR_X] = x_pu
        branch[i, BR_B] = 0.0  # Transformers usually don't have shunt susceptance
        
        # Set tap ratio and phase shift
        branch[i, TAP] = 1.0  # Default tap ratio is 1.0
        branch[i, SHIFT] = 0.0  # Default phase shift angle is 0.0
        
        # Set rated capacity
        branch[i, RATE_A] = case.baseMVA 
        
        # Set branch status
        branch[i, BR_STATUS] = transformer.in_service ? 1.0 : 0.0
        
        # Set angle limits
        branch[i, ANGMIN] = -360.0
        branch[i, ANGMAX] = 360.0
    end
    
    # Add transformer branch data to JPC structure
    if isempty(jpc.branchAC)
        jpc.branchAC = branch
    else
        jpc.branchAC = [jpc.branchAC; branch]
    end
end

function JPC_gens_process(case::JuliaPowerCase, jpc::JPC)
    # Count various generation equipment
    n_gen = length(case.gensAC)
    n_sgen = length(case.sgensAC)
    n_ext = length(case.ext_grids)
    
    # Calculate total generation equipment
    total_gens = n_gen + n_sgen + n_ext
    
    if total_gens == 0
        return  # If no generation equipment, return directly
    end
    
    # Create generator matrix, rows equal to number of generation equipment, columns equal to 26
    gen_data = zeros(total_gens, 26)
    
    # Process external grids (usually as slack nodes/reference nodes)
    for (i, ext) in enumerate(case.ext_grids)
        if !ext.in_service
            continue
        end
        
        bus_idx = ext.bus
        
        # Fill generator data
        gen_data[i, :] = [
            bus_idx,        # Generator connected bus number
            0.0,            # Active power output (MW)
            0.0,            # Reactive power output (MVAr)
            9999.0,         # Maximum reactive power output (MVAr)
            -9999.0,        # Minimum reactive power output (MVAr)
            ext.vm_pu,      # Voltage magnitude setpoint (p.u.)
            case.baseMVA,   # Generator base capacity (MVA)
            1.0,            # Generator status (1=running, 0=shutdown)
            9999.0,         # Maximum active power output (MW)
            -9999.0,        # Minimum active power output (MW)
            0.0,            # PQ capability curve low end active power output (MW)
            0.0,            # PQ capability curve high end active power output (MW)
            0.0,            # PC1 minimum reactive power output (MVAr)
            0.0,            # PC1 maximum reactive power output (MVAr)
            0.0,            # PC2 minimum reactive power output (MVAr)
            0.0,            # PC2 maximum reactive power output (MVAr)
            0.0,            # AGC regulation rate (MW/min)
            0.0,            # 10-minute reserve regulation rate (MW)
            0.0,            # 30-minute reserve regulation rate (MW)
            0.0,            # Reactive power regulation rate (MVAr/min)
            1.0,            # Area participation factor
            2.0,            # Generator model (2=polynomial cost model)
            0.0,            # Startup cost (USD)
            0.0,            # Shutdown cost (USD)
            3.0,            # Number of polynomial cost function coefficients
            0.0             # Cost function parameters (to be extended later)
        ]
        
        # Update bus type to reference node (REF/slack node)
        jpc.busAC[bus_idx, 2] = 3  # 3 indicates REF node
    end
    
    # Process conventional generators (usually as PV nodes)
    offset = n_ext
    for (i, gen) in enumerate(case.gensAC)
        if !gen.in_service
            continue
        end
        
        idx = i + offset
        bus_idx = gen.bus
        
        # Calculate reactive power (if not directly given)
        q_mvar = 0.0
        if hasfield(typeof(gen), :q_mvar)
            q_mvar = gen.q_mvar
        else
            # Calculate reactive power based on power factor
            p_mw = gen.p_mw * gen.scaling
            if gen.cos_phi > 0 && p_mw > 0
                q_mvar = p_mw * tan(acos(gen.cos_phi))
            end
        end
        
        # Base capacity
        mbase = gen.sn_mva > 0 ? gen.sn_mva : case.baseMVA
        
        # Ramp rate parameters
        ramp_agc = hasfield(typeof(gen), :ramp_up_rate_mw_per_min) ? 
                   gen.ramp_up_rate_mw_per_min : 
                   (gen.max_p_mw - gen.min_p_mw) / 10
        ramp_10 = hasfield(typeof(gen), :ramp_up_rate_mw_per_min) ? 
                  gen.ramp_up_rate_mw_per_min * 10 : 
                  gen.max_p_mw - gen.min_p_mw
        ramp_30 = hasfield(typeof(gen), :ramp_up_rate_mw_per_min) ? 
                  gen.ramp_up_rate_mw_per_min * 30 : 
                  gen.max_p_mw - gen.min_p_mw
        
        # Fill generator data
        gen_data[idx, :] = [
            bus_idx,                               # Generator connected bus number
            gen.p_mw * gen.scaling,                # Active power output (MW)
            q_mvar,                                # Reactive power output (MVAr)
            gen.max_q_mvar,                        # Maximum reactive power output (MVAr)
            gen.min_q_mvar,                        # Minimum reactive power output (MVAr)
            gen.vm_pu,                             # Voltage magnitude setpoint (p.u.)
            mbase,                                 # Generator base capacity (MVA)
            1.0,                                   # Generator status (1=running, 0=shutdown)
            gen.max_p_mw,                          # Maximum active power output (MW)
            gen.min_p_mw,                          # Minimum active power output (MW)
            gen.min_p_mw,                          # PQ capability curve low end active power output (MW)
            gen.max_p_mw,                          # PQ capability curve high end active power output (MW)
            gen.min_q_mvar,                        # PC1 minimum reactive power output (MVAr)
            gen.max_q_mvar,                        # PC1 maximum reactive power output (MVAr)
            gen.min_q_mvar,                        # PC2 minimum reactive power output (MVAr)
            gen.max_q_mvar,                        # PC2 maximum reactive power output (MVAr)
            ramp_agc,                              # AGC regulation rate (MW/min)
            ramp_10,                               # 10-minute reserve regulation rate (MW)
            ramp_30,                               # 30-minute reserve regulation rate (MW)
            (gen.max_q_mvar - gen.min_q_mvar)/10,  # Reactive power regulation rate (MVAr/min)
            1.0,                                   # Area participation factor
            2.0,                                   # Generator model (2=polynomial cost model)
            0.0,                                   # Startup cost (USD)
            0.0,                                   # Shutdown cost (USD)
            3.0,                                   # Number of polynomial cost function coefficients
            0.0                                    # Cost function parameters (to be extended later)
        ]
        
        # If bus not yet set as reference node, set as PV node
        if jpc.busAC[bus_idx, 2] != 3  # 3 indicates REF node
            jpc.busAC[bus_idx, 2] = 2  # 2 indicates PV node
        end
    end
    
    # Process static generators (usually as PQ nodes, but can be PV nodes if they have voltage control capability)
    offset = n_ext + n_gen
    for (i, sgen) in enumerate(case.sgensAC)
        if !sgen.in_service
            continue
        end
        
        idx = i + offset
        bus_idx = sgen.bus
        
        # Fill generator data
        gen_data[idx, :] = [
            bus_idx,                                # Generator connected bus number
            sgen.p_mw * sgen.scaling,               # Active power output (MW)
            sgen.q_mvar * sgen.scaling,             # Reactive power output (MVAr)
            sgen.max_q_mvar,                        # Maximum reactive power output (MVAr)
            sgen.min_q_mvar,                        # Minimum reactive power output (MVAr)
            1.0,                                    # Voltage magnitude setpoint (p.u.)
            case.baseMVA,                           # Generator base capacity (MVA)
            1.0,                                    # Generator status (1=running, 0=shutdown)
            sgen.max_p_mw,                          # Maximum active power output (MW)
            sgen.min_p_mw,                          # Minimum active power output (MW)
            sgen.min_p_mw,                          # PQ capability curve low end active power output (MW)
            sgen.max_p_mw,                          # PQ capability curve high end active power output (MW)
            sgen.min_q_mvar,                        # PC1 minimum reactive power output (MVAr)
            sgen.max_q_mvar,                        # PC1 maximum reactive power output (MVAr)
            sgen.min_q_mvar,                        # PC2 minimum reactive power output (MVAr)
            sgen.max_q_mvar,                        # PC2 maximum reactive power output (MVAr)
            (sgen.max_p_mw - sgen.min_p_mw) / 10,   # AGC regulation rate (MW/min)
            sgen.max_p_mw - sgen.min_p_mw,          # 10-minute reserve regulation rate (MW)
            sgen.max_p_mw - sgen.min_p_mw,          # 30-minute reserve regulation rate (MW)
            (sgen.max_q_mvar - sgen.min_q_mvar)/10, # Reactive power regulation rate (MVAr/min)
            1.0,                                    # Area participation factor
            2.0,                                    # Generator model (2=polynomial cost model)
            0.0,                                    # Startup cost (USD)
            0.0,                                    # Shutdown cost (USD)
            3.0,                                    # Number of polynomial cost function coefficients
            0.0                                     # Cost function parameters (to be extended later)
        ]
        
        # If static generator is controllable and bus not yet set as REF or PV node, possibly set as PV node
        if sgen.controllable && jpc.busAC[bus_idx, 2] == 1  # 1 indicates PQ node
            jpc.busAC[bus_idx, 2] = 2  # 2 indicates PV node
        end
    end
    
    # Remove unused rows (corresponding to non-operational generation equipment)
    active_rows = findall(x -> x > 0, gen_data[:, 8])  # Column 8 is GEN_STATUS
    gen_data = gen_data[active_rows, :]
    
    # Store generator data in JPC structure
    jpc.genAC = gen_data
    
    # Ensure at least one slack node
    if !any(jpc.busAC[:, 2] .== 3) && size(gen_data, 1) > 0  # 3 indicates REF node
        # If no slack node, choose first generator bus as slack node
        first_gen_bus = Int(gen_data[1, 1])
        jpc.busAC[first_gen_bus, 2] = 3  # 3 indicates REF node
    end
end

function JPC_battery_gens_process(case::JuliaPowerCase, jpc::JPC)
    # Create virtual generators for battery virtual nodes
    batteries = deepcopy(case.storageetap)
    num_batteries = length(batteries)
    
    # If no batteries, return directly
    if num_batteries == 0
        return jpc
    end
    
    # Get current busDC size, used to determine virtual node numbering
    busDC_size = size(jpc.busDC, 1) - num_batteries
    
    # Create battery virtual generator matrix
    # genDC matrix typically includes these columns:
    # [GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, ...]
    # Specific column count should match your genDC structure
    num_gen_cols = size(jpc.genAC, 2)
    if num_gen_cols == 0  # If genDC is empty, set a default column count
        num_gen_cols = 10
    end
    
    battery_gens = zeros(num_batteries, num_gen_cols)
     # Create storage matrix
    num_storage_cols = 5  # Based on column count defined in idx_ess function
    storage_matrix = zeros(num_batteries, num_storage_cols)
    
    for (i, battery) in enumerate(batteries)
        # Calculate battery virtual node number
        virtual_bus = busDC_size + i
        
        # Calculate battery power capacity (based on battery parameters)
        # Using simplified calculation here, actual should be based on battery characteristics
        power_capacity = battery.package * battery.voc
        
        # Fill virtual generator matrix
        battery_gens[i, 1] = virtual_bus       # GEN_BUS: Generator connected node number
        battery_gens[i, 2] = 0.0               # PG: Initial active power output (MW), initially set to 0
        battery_gens[i, 3] = 0.0               # QG: Initial reactive power output (MVAR), usually 0 for DC systems
        
        # Set reactive power limits (usually not considered for DC systems)
        battery_gens[i, 4] = 0.0               # QMAX: Maximum reactive power output
        battery_gens[i, 5] = 0.0               # QMIN: Minimum reactive power output
        
        # Set voltage and base power
        battery_gens[i, 6] = 1.0               # VG: Voltage setpoint (p.u.)
        battery_gens[i, 7] = case.baseMVA      # MBASE: Generator base power (MVA)
        
        # Set generator status
        battery_gens[i, 8] = battery.in_service ? 1.0 : 0.0  # GEN_STATUS: Generator status
        
        # Set active power limits (charging is negative, discharging is positive)
        battery_gens[i, 9] = power_capacity    # PMAX: Maximum active power output (MW), discharge power
        battery_gens[i, 10] = -power_capacity  # PMIN: Minimum active power output (MW), charge power

         # Fill storage matrix
        storage_matrix[i, ESS_BUS] = virtual_bus               # ESS_BUS: Connected node number
        # storage_matrix[i, ESS_POWER_CAPACITY] = power_capacity # ESS_POWER_CAPACITY: Power capacity (MW)
        # storage_matrix[i, ESS_ENERGY_CAPACITY] = 0
        # storage_matrix[i, ESS_AREA] = 1                        # ESS_AREA: Area number, default is 1
        
        # If genDC has more columns, set other parameters as needed
        if num_gen_cols > 10
            # For example, set ramp rate limits, cost coefficients, etc.
            # Here you need to set according to your system specific requirements
            for j in 11:num_gen_cols
                battery_gens[i, j] = 0.0  # Default set to 0
            end
        end
    end
    
    # Add battery virtual generators to genDC
    if isempty(jpc.genDC)
        jpc.genDC = battery_gens
    else
        jpc.genDC = [jpc.genDC; battery_gens]
    end
    
    # Add storage device information to storage
    if !isdefined(jpc, :storageetap) || isempty(jpc.storageetap)
        jpc.storageetap = storage_matrix
    else
        jpc.storageetap = [jpc.storageetap; storage_matrix]
    end

    return jpc
end


function JPC_loads_process(case::JuliaPowerCase, jpc::JPC)
    # Process load data, convert to JPC format and update busAC's PD and QD
    
    # Filter operational loads
    in_service_loads = filter(load -> load.in_service == true, case.loadsAC)
    
    # If no operational loads, return directly
    if isempty(in_service_loads)
        return
    end
    
    # Create an empty matrix, rows equal to number of loads, columns equal to 8
    num_loads = length(in_service_loads)
    load_matrix = zeros(num_loads, 8)
    
    # Create a dictionary to accumulate loads connected to the same bus
    bus_load_sum = Dict{Int, Vector{Float64}}()
    
    for (i, load) in enumerate(in_service_loads)
        # Calculate actual active and reactive loads (considering scaling factor)
        # if mode =="1_ph_pf"
            actual_p_mw = load.p_mw * load.scaling
            actual_q_mvar = load.q_mvar * load.scaling
        # else
        #     actual_p_mw = load.p_mw * load.scaling / 3.0
        #     actual_q_mvar = load.q_mvar * load.scaling / 3.0
        # end
        
        # Fill each row of the load matrix
        load_matrix[i, :] = [
            i,              # Load connected bus number
            load.bus,                     # Load number
            1.0,                   # Load status (1=operational)
            actual_p_mw,           # Active load (MW)
            actual_q_mvar,         # Reactive load (MVAr)
            load.const_z_percent/100,  # Constant impedance load percentage
            load.const_i_percent/100,  # Constant current load percentage
            load.const_p_percent/100   # Constant power load percentage
        ]
        
        # Accumulate loads connected to the same bus
        bus_idx = load.bus
        if haskey(bus_load_sum, bus_idx)
            bus_load_sum[bus_idx][1] += actual_p_mw
            bus_load_sum[bus_idx][2] += actual_q_mvar
        else
            bus_load_sum[bus_idx] = [actual_p_mw, actual_q_mvar]
        end
    end
    
    # Store load data in JPC structure
    jpc.loadAC = load_matrix
    
    # Update PD and QD fields in busAC matrix
    for (bus_idx, load_values) in bus_load_sum
        # Find corresponding bus row
        bus_row = findfirst(x -> x == bus_idx, jpc.busAC[:, 1])
        
        if !isnothing(bus_row)
            # Update PD (column 3) and QD (column 4)
            jpc.busAC[bus_row, PD] = load_values[1]  # PD - Active load (MW)
            jpc.busAC[bus_row, QD] = load_values[2]  # QD - Reactive load (MVAr)
        end
    end
end

function JPC_dcloads_process(case::JuliaPowerCase, jpc::JPC)
    # Process DC load data, convert to JPC format and update busDC's PD and QD
    
    # Filter operational DC loads
    in_service_dcloads = filter(dcload -> dcload.in_service == true, case.loadsDC)
    
    # If no operational DC loads, return directly
    if isempty(in_service_dcloads)
        return
    end
    
    # Create an empty matrix, rows equal to number of DC loads, columns equal to 8
    num_dcloads = length(in_service_dcloads)
    dcload_matrix = zeros(num_dcloads, 8)
    
    for (i, dcload) in enumerate(in_service_dcloads)
        # Fill each row of the DC load matrix
        dcload_matrix[i, :] = [
            dcload.index,              # DC load number
            dcload.bus,     # DC load connected bus number
            1.0,            # DC load status (1=operational)
            dcload.p_mw * dcload.scaling,  # Active load (MW)
            0.0,            # Reactive load (MVAr)
            dcload.const_z_percent/100,           # Constant impedance percentage (default 0)
            dcload.const_i_percent/100,           # Constant current percentage (default 0)
            dcload.const_p_percent/100            # Constant power percentage (default 0)
        ]
        
        # Update PD and QD fields in busDC matrix
        bus_row = findfirst(x -> x == dcload.bus, jpc.busDC[:, 1])
        
        if !isnothing(bus_row)
            jpc.busDC[bus_row, PD] += dcload_matrix[i, 4]  # PD - Active load (MW)
            jpc.busDC[bus_row, QD] += dcload_matrix[i, 5]  # QD - Reactive load (MVAr)
        end
    end
    
    # Store DC load data in JPC structure
    jpc.loadDC = dcload_matrix

    return jpc
end

function JPC_pv_process(case::JuliaPowerCase, jpc::JPC)
    # Process PV generator data, convert to JPC format and update busAC's PD and QD
    
    # Filter operational PV generators
    in_service_pvs = filter(pv -> pv.in_service == true, case.pvarray)
    
    # If no operational PV generators, return directly
    if isempty(in_service_pvs)
        return
    end
    
    # Create an empty matrix, rows equal to number of PV generators, columns equal to 8
    num_pvs = length(in_service_pvs)
    pv_matrix = zeros(num_pvs, 9)
    
    for (i, pv) in enumerate(in_service_pvs)
        Voc = (pv.voc + (pv.temperature - 25)*pv.β_voc )* pv.numpanelseries
        Vmpp = pv.vmpp * pv.numpanelseries
        Isc = (pv.isc + (pv.temperature - 25)*pv.α_isc)*(pv.irradiance/1000.0) * pv.numpanelparallel
        Impp = pv.impp * (pv.irradiance/1000.0) * pv.numpanelparallel

        # Voc = (pv.voc + (pv.temperature - 25)*pv.β_voc + pv.γ_voc*log(pv.irradiance/1000.0)) * pv.numpanelseries
        # Vmpp = (pv.vmpp + pv.γ_vmpp*log(pv.irradiance/1000.0)) * pv.numpanelseries
        # Isc = (pv.isc + (pv.temperature - 25)*pv.α_isc)*(pv.irradiance/1000.0) * pv.numpanelparallel
        # Impp = pv.impp*(pv.irradiance/1000.0) * pv.numpanelparallel
        # Fill each row of the PV generator matrix
        pv_matrix[i, :] = [
            i,              # PV generator number
            pv.bus,         # PV generator connected bus number
            Voc,         # PV generator rated voltage (V)
            Vmpp,        # PV generator rated voltage (V)
            Isc,         # PV generator short circuit current (A)
            Impp,        # PV generator rated current (A)
            pv.irradiance,  # PV generator irradiance (W/m²)
            1.0,            # area
            1.0,            # PV generator status (1=operational)
        ]
        
        # # Update PD and QD fields in busAC matrix
        # bus_row = findfirst(x -> x == pv.bus, jpc.busAC[:, 1])
        
        # if !isnothing(bus_row)
        #     jpc.busAC[bus_row, PD] += pv_matrix[i, 4]  # PD - Active load (MW)
        #     jpc.busAC[bus_row, QD] += pv_matrix[i, 5]  # QD - Reactive load (MVAr)
        # end
    end
    
    # Store PV generator data in JPC structure
    jpc.pv = pv_matrix

    return jpc
    
end

function JPC_ac_pv_system_process(case::JuliaPowerCase, jpc::JPC)
    # Process AC side PV system data, convert to generators or loads based on control mode
    
    # Filter operational AC side PV systems
    in_service_ac_pvs = filter(ac_pv -> ac_pv.in_service == true, case.ACPVSystems)
    
    # If no operational AC side PV systems, return directly
    if isempty(in_service_ac_pvs)
        return jpc
    end
    
    # Create an empty matrix, rows equal to number of AC side PV systems, columns equal to 13
    num_ac_pvs = length(in_service_ac_pvs)
    ac_pv_matrix = zeros(num_ac_pvs, 15)
    for (i, ac_pv) in enumerate(in_service_ac_pvs)
        Vmpp = ac_pv.vmpp * ac_pv.numpanelseries
        Voc = (ac_pv.voc + (ac_pv.temperature - 25) * ac_pv.β_voc) * ac_pv.numpanelseries
        Isc = (ac_pv.isc + (ac_pv.temperature - 25) * ac_pv.α_isc) * (ac_pv.irradiance / 1000.0) * ac_pv.numpanelparallel
        Impp = ac_pv.impp * ac_pv.numpanelparallel

        p_max = Vmpp * Impp / 1000000.0 * (1-ac_pv.loss_percent)# Maximum active output (MW)

        if ac_pv.control_mode == "Voltage Control"
            mode = 1
        else
            mode = 0 
        end
        
        # Fill each row of the AC side PV system matrix
        ac_pv_matrix[i, :] = [
            i,                # AC PV system number
            ac_pv.bus,            # Connected bus number
            Voc,               # PV system rated voltage (V)
            Vmpp,              # PV system rated voltage (V)
            Isc,               # PV system short circuit current (A)
            Impp,              # PV system rated current (A)
            ac_pv.irradiance,  # PV system irradiance (W/m²)
            ac_pv.loss_percent,
            mode,              # Control mode (0=reactive control, 1=voltage control)
            ac_pv.p_mw,           # Active power output (MW)
            ac_pv.q_mvar,         # Reactive power output (MVAr)
            ac_pv.max_q_mvar,     # Reactive power upper limit (MVAr)
            ac_pv.min_q_mvar,     # Reactive power lower limit (MVAr)
            1,            # Area number
            ac_pv.in_service ? 1.0 : 0.0  # PV system status (1=operational, 0=shutdown)
        ]
    end
    # Store AC side PV system data in JPC structure
    jpc.pv_acsystem = ac_pv_matrix


    # # Separate PV systems with different control modes
    # voltage_control_pvs = filter(ac_pv -> ac_pv.control_mode == "Voltage Control", in_service_ac_pvs)
    # mvar_control_pvs = filter(ac_pv -> ac_pv.control_mode == "Mvar Control", in_service_ac_pvs)
    
    # # Process voltage control mode PV systems (create generators, modify bus type to PV)
    # if !isempty(voltage_control_pvs)
    #     num_voltage_pvs = length(voltage_control_pvs)
    #     voltage_pv_matrix = zeros(num_voltage_pvs, 26)  # Generator matrix column count
        
    #     for (i, ac_pv) in enumerate(voltage_control_pvs)
    #         # Get current maximum generator number
    #         max_gen_id = isempty(jpc.genAC) ? 0 : maximum(jpc.genAC[:, 1])
    #         gen_id = max_gen_id + i

     #         Vmpp = ac_pv.vmpp * ac_pv.numpanelseries
    #         Voc = (ac_pv.voc + (ac_pv.temperature - 25) * ac_pv.β_voc) * ac_pv.numpanelseries
    #         Isc = (ac_pv.isc + (ac_pv.temperature - 25) * ac_pv.α_isc) * (ac_pv.irradiance / 1000.0) * ac_pv.numpanelparallel
    #         Impp = ac_pv.impp * ac_pv.numpanelparallel

    #         p_max = Vmpp * Impp / 1000000.0 * (1-ac_pv.loss_percent)# Maximum active output (MW)
    #         findfirst_bus = findfirst(x -> x == ac_pv.bus, jpc.busAC[:, 1])
    #         jpc.busAC[findfirst_bus, BUS_TYPE] = 2 # Set bus type to PV node
            
    #         voltage_pv_matrix[i, :] = [
    #             ac_pv.bus,                # Connected bus number
    #             ac_pv.p_mw,              # Active power output (MW)
    #             ac_pv.q_mvar,            # Reactive power output (MVAr)
    #             ac_pv.max_q_mvar,        # Reactive power upper limit (MVAr)
    #             ac_pv.min_q_mvar,        # Reactive power lower limit (MVAr)
    #             hasfield(typeof(ac_pv), :vm_ac_pu) ? ac_pv.vm_ac_pu : 1.0, # Voltage setpoint (p.u.)
    #             case.baseMVA,            # Generator base capacity (MVA)
    #             1.0,                     # Generator status (1=operational)
    #             p_max,                   # Active power upper limit (MW)
    #             0.0,                     # Active power lower limit (MW)
    #             0.0,                     # PQ capability curve low end active output (MW)
    #             0.0,                     # PQ capability curve high end active output (MW)
    #             0.0,                     # PC1 minimum reactive output (MVAr)
    #             0.0,                     # PC1 maximum reactive output (MVAr)
    #             0.0,                     # PC2 minimum reactive output (MVAr)
    #             0.0,                     # PC2 maximum reactive output (MVAr)
    #             0.0,                     # AGC regulation rate (MW/min)
    #             0.0,                     # 10-minute reserve regulation rate (MW)
    #             0.0,                     # 30-minute reserve regulation rate (MW)
    #             0.0,                     # Reactive power regulation rate (MVAr/min)
    #             0.0,                     # Area participation factor
    #             0.0,                     # Generator model (0=no model)
    #             0.0,                     # Startup cost (USD)
    #             0.0,                     # Shutdown cost (USD)
    #             0.0,                     # Number of polynomial cost function coefficients
    #             0.0                      # Cost function parameters (to be extended later)
    #         ]
    #     end
        
    #     # Add voltage control PV systems to generator matrix
    #     if isempty(jpc.genAC)
    #         jpc.genAC = voltage_pv_matrix
    #     else
    #         jpc.genAC = vcat(jpc.genAC, voltage_pv_matrix)
    #     end
    # end
    
    # # Process reactive power control mode PV systems (create generators, but don't modify bus type)
    # if !isempty(mvar_control_pvs)
    #     num_mvar_pvs = length(mvar_control_pvs)
    #     mvar_pv_matrix = zeros(num_mvar_pvs, 26)  # Generator matrix column count
        
    #     for (i, ac_pv) in enumerate(mvar_control_pvs)
    #         # Get current maximum generator number
    #         current_max_gen_id = isempty(jpc.genAC) ? 0 : maximum(jpc.genAC[:, 1])
    #         # If there are already voltage control generators, need to continue numbering from there
    #         gen_id = current_max_gen_id + length(voltage_control_pvs) + i

    #         Vmpp = ac_pv.vmpp * ac_pv.numpanelseries
    #         Voc = (ac_pv.voc + (ac_pv.temperature - 25) * ac_pv.β_voc) * ac_pv.numpanelseries
    #         Isc = (ac_pv.isc + (ac_pv.temperature - 25) * ac_pv.α_isc) * (ac_pv.irradiance / 1000.0) * ac_pv.numpanelparallel
    #         Impp = ac_pv.impp * ac_pv.numpanelparallel

    #         p_max = Vmpp * Impp / 1000000.0 * (1-ac_pv.loss_percent)# Maximum active output (MW)
            
    #         # Note: MVar Control mode does not modify bus type, keeps original type (usually PQ node)
            
    #         mvar_pv_matrix[i, :] = [
    #             ac_pv.bus,                # Connected bus number
    #             ac_pv.p_mw,              # Active power output (MW) - MPPT power
    #             ac_pv.q_mvar,            # Reactive power output (MVAr) - Fixed reactive
    #             ac_pv.max_q_mvar,        # Reactive power upper limit (MVAr)
    #             ac_pv.min_q_mvar,        # Reactive power lower limit (MVAr)
    #             1.0,                     # Voltage setpoint (p.u.) - MVar control doesn't control voltage
    #             case.baseMVA,            # Generator base capacity (MVA)
    #             1.0,                     # Generator status (1=operational)
    #             p_max,                   # Active power upper limit (MW)
    #             0.0,                     # Active power lower limit (MW)
    #             0.0,                     # PQ capability curve low end active output (MW)
    #             0.0,                     # PQ capability curve high end active output (MW)
    #             0.0,                     # PC1 minimum reactive output (MVAr)
    #             0.0,                     # PC1 maximum reactive output (MVAr)
    #             0.0,                     # PC2 minimum reactive output (MVAr)
    #             0.0,                     # PC2 maximum reactive output (MVAr)
    #             0.0,                     # AGC regulation rate (MW/min)
    #             0.0,                     # 10-minute reserve regulation rate (MW)
    #             0.0,                     # 30-minute reserve regulation rate (MW)
    #             0.0,                     # Reactive power regulation rate (MVAr/min)
    #             0.0,                     # Area participation factor
    #             0.0,                     # Generator model (0=no model)
    #             0.0,                     # Startup cost (USD)
    #             0.0,                     # Shutdown cost (USD)
    #             0.0,                     # Number of polynomial cost function coefficients
    #             0.0                      # Cost function parameters (to be extended later)
    #         ]
    #     end
        
    #     # Add reactive power control PV systems to generator matrix
    #     if isempty(jpc.genAC)
    #         jpc.genAC = mvar_pv_matrix
    #     else
    #         jpc.genAC = vcat(jpc.genAC, mvar_pv_matrix)
    #     end
    # end
    
    return jpc
end



function JPC_inverters_process(case::JuliaPowerCase, jpc::JPC)
    # Process inverter data, convert to JPC format and update busAC and busDC loads
    
    # Filter operational inverters
    in_service_inverters = filter(inverter -> inverter.in_service == true, case.converters)
    
    # If no operational inverters, return directly
    if isempty(in_service_inverters)
        return jpc
    end
    
    # Get current load count, used for new load numbering
    nld_ac = size(jpc.loadAC, 1)  # AC side load count
    nld_dc = size(jpc.loadDC, 1)  # DC side load count
    
    # Create storage for new load records
    # Use matrices instead of arrays to store new loads
    num_cols_ac = size(jpc.loadAC, 2)
    num_cols_dc = size(jpc.loadDC, 2)
    
    # Calculate maximum possible number of loads to add (each inverter adds at most one load)
    max_new_loads = length(in_service_inverters)
    new_loads_ac = zeros(0, num_cols_ac)  # Create an empty matrix, rows=0, columns same as loadAC
    new_loads_dc = zeros(0, num_cols_dc)  # Create an empty matrix, rows=0, columns same as loadDC

    # Create empty converter matrix
    converters = zeros(0, 18)
    
    # Track count of new loads
    new_ac_load_count = 0
    new_dc_load_count = 0

    
    
   for (i, inverter) in enumerate(in_service_inverters)
        # Add connection relationship to converter matrix
        converter = zeros(1, 18)  # Create one row
        
        # Inverter operation mode
        mode = inverter.control_mode
        if mode == "δs_Us"
            converter[1, CONV_MODE] = 1.0  # δs_Us mode inverters don't need settings
        elseif mode == "Ps_Qs"
            converter[1, CONV_MODE] = 0.0  # Ps_Qs mode inverters
        elseif mode == "Ps_Us"
            converter[1, CONV_MODE] = 3.0  # Ps_Us mode inverters
        elseif mode == "Udc_Qs"
            converter[1, CONV_MODE] = 4.0  # Udc_Qs mode inverters
        elseif mode == "Udc_Us"
            converter[1, CONV_MODE] = 5.0  # Udc_Us mode inverters
        elseif mode == "Droop_Udc_Qs"
            converter[1, CONV_MODE] = 6.0  # Droop_Udc_Qs mode inverters
        elseif mode == "Droop_Udc_Us"
            converter[1, CONV_MODE] = 7.0  # Droop_Udc_Us mode inverters
        else
            @warn "Inverter $i control mode $mode unknown or unsupported, default enabling Ps_Qs"
            converter[1, CONV_MODE] = 0.0  # Set to default value
        end

        # Calculate AC side power
        p_ac = -inverter.p_mw 
        q_ac = -inverter.q_mvar 
        
        # Calculate DC side power (considering efficiency)
        efficiency = 1.0 - inverter.loss_percent   # Convert to decimal
        
        if p_ac <= 0  # AC side outputs power, DC side inputs power
            p_dc = -p_ac / efficiency  # Negative value, indicating power consumed by DC side
        else  # AC side inputs power, DC side outputs power
            p_dc = -p_ac * efficiency  # Positive value, indicating power output by DC side
        end

        converter[1,CONV_ACBUS] = inverter.bus_ac
        converter[1,CONV_DCBUS] = inverter.bus_dc
        converter[1,CONV_INSERVICE] = 1.0
        converter[1,CONV_P_AC] = p_ac
        converter[1,CONV_Q_AC] = q_ac
        converter[1,CONV_P_DC] = p_dc
        converter[1,CONV_EFF] = efficiency
        converter[1,CONV_DROOP_KP] = inverter.droop_kv
        converters = vcat(converters, converter)
        
        # Get AC and DC bus row indices
        ac_bus_row = findfirst(x -> x == inverter.bus_ac, jpc.busAC[:, 1])
        dc_bus_row = findfirst(x -> x == inverter.bus_dc, jpc.busDC[:, 1])
        
        # Decide whether to modify load information based on control mode
        if mode =="δs_Us"
            # δs_Us mode: No modifications
        elseif mode == "Ps_Qs"
            # Ps_Qs mode: Modify both AC side active and reactive, and DC side active
            if !isnothing(ac_bus_row)
                jpc.busAC[ac_bus_row, PD] += p_ac  # PD - Active load (MW)
                jpc.busAC[ac_bus_row, QD] += q_ac  # QD - Reactive load (MVAr)
            end
            
            if !isnothing(dc_bus_row)
                jpc.busDC[dc_bus_row, PD] += p_dc  # PD - Active load (MW)
            end
            
            # Process AC side load
            existing_load_indices_ac = findall(x -> x == inverter.bus_ac, jpc.loadAC[:, 2])
            
            if isempty(existing_load_indices_ac)
                # If no load connected to the same node, create new load record
                new_ac_load_count += 1
                new_load_ac = zeros(1, num_cols_ac)  # Create one row
                new_load_ac[1, LOAD_I] = nld_ac + new_ac_load_count  # Load number
                new_load_ac[1, LOAD_CND] = inverter.bus_ac             # Bus number
                new_load_ac[1, LOAD_STATUS] = 1.0                         # Status (1=operational)
                new_load_ac[1, LOAD_PD] = p_ac                        # Active power (MW)
                new_load_ac[1, LOAD_QD] = q_ac                        # Reactive power (MVAr)
                # Inverter defaults to constant power load
                new_load_ac[1, LOADZ_PERCENT] = 0.0                         # Constant impedance ratio
                new_load_ac[1, LOADI_PERCENT] = 0.0                         # Constant current ratio
                new_load_ac[1, LOADP_PERCENT] = 1.0                         # Constant power ratio
                
                # Add to new load matrix
                new_loads_ac = vcat(new_loads_ac, new_load_ac)
            else
                # If loads connected to the same node exist, update these loads
                for idx in existing_load_indices_ac
                    # Get original load power and ZIP ratios
                    orig_p = jpc.loadAC[idx, LOAD_PD]
                    orig_q = jpc.loadAC[idx, LOAD_QD]
                    orig_z_percent = jpc.loadAC[idx, LOADZ_PERCENT]
                    orig_i_percent = jpc.loadAC[idx, LOADI_PERCENT]
                    orig_p_percent = jpc.loadAC[idx, LOADP_PERCENT]
                    
                    # Calculate new total power
                    new_p = orig_p + p_ac
                    new_q = orig_q + q_ac
                    
                    # Recalculate ZIP ratios (weighted average)
                    # Avoid division by zero
                    if new_p != 0
                        # Original load weight
                        w_orig = abs(orig_p) / abs(new_p)
                        # Inverter load weight (default constant power)
                        w_inv = abs(p_ac) / abs(new_p)
                        
                        # Calculate new ZIP ratios
                        new_z_percent = orig_z_percent * w_orig + 0.0 * w_inv
                        new_i_percent = orig_i_percent * w_orig + 0.0 * w_inv
                        new_p_percent = orig_p_percent * w_orig + 1.0 * w_inv
                        
                        # Ensure ratio sum is 1
                        sum_percent = new_z_percent + new_i_percent + new_p_percent
                        if sum_percent != 0
                            new_z_percent /= sum_percent
                            new_i_percent /= sum_percent
                            new_p_percent /= sum_percent
                        else
                            # If sum is 0, set to default values
                            new_z_percent = 0.0
                            new_i_percent = 0.0
                            new_p_percent = 1.0
                        end
                    else
                        # If new total power is 0, keep original ZIP ratios
                        new_z_percent = orig_z_percent
                        new_i_percent = orig_i_percent
                        new_p_percent = orig_p_percent
                    end
                    
                    # Update load matrix
                    jpc.loadAC[idx, LOAD_PD] = new_p
                    jpc.loadAC[idx, LOAD_QD] = new_q
                    jpc.loadAC[idx, LOADZ_PERCENT] = new_z_percent
                    jpc.loadAC[idx, LOADI_PERCENT] = new_i_percent
                    jpc.loadAC[idx, LOADP_PERCENT] = new_p_percent
                end
            end
            
            # Process DC side load
            existing_load_indices_dc = findall(x -> x == inverter.bus_dc, jpc.loadDC[:, 2])
            
            if isempty(existing_load_indices_dc)
                # If no load connected to the same node, create new load record
                new_dc_load_count += 1
                new_load_dc = zeros(1, num_cols_dc)  # Create one row
                new_load_dc[1, LOAD_I] = nld_dc + new_dc_load_count  # Load number
                new_load_dc[1, LOAD_CND] = inverter.bus_dc             # Bus number
                new_load_dc[1, LOAD_STATUS] = 1.0                         # Status (1=operational)
                new_load_dc[1, LOAD_PD] = p_dc                        # Active power (MW)
                new_load_dc[1, LOAD_QD] = 0.0                         # Reactive power (MVAr)
                # DC system has no reactive
                # DC side defaults to constant power load
                new_load_dc[1, LOADZ_PERCENT] = 0.0                         # Constant impedance ratio
                new_load_dc[1, LOADI_PERCENT] = 0.0                         # Constant current ratio
                new_load_dc[1, LOADP_PERCENT] = 1.0                         # Constant power ratio
                
                # Add to new load matrix
                new_loads_dc = vcat(new_loads_dc, new_load_dc)
            else
                # If loads connected to the same node exist, update these loads
                for idx in existing_load_indices_dc
                    # Get original load power and ZIP ratios
                    orig_p = jpc.loadDC[idx, 4]
                    orig_z_percent = jpc.loadDC[idx, LOADZ_PERCENT]
                    orig_i_percent = jpc.loadDC[idx, LOADI_PERCENT]
                    orig_p_percent = jpc.loadDC[idx, LOADP_PERCENT]
                    
                    # Calculate new total power
                    new_p = orig_p + p_dc
                    
                    # Recalculate ZIP ratios (weighted average)
                    # Avoid division by zero
                    if new_p != 0
                        # Original load weight
                        w_orig = abs(orig_p) / abs(new_p)
                        # Inverter load weight (default constant power)
                        w_inv = abs(p_dc) / abs(new_p)
                        
                        # Calculate new ZIP ratios
                        new_z_percent = orig_z_percent * w_orig + 0.0 * w_inv
                        new_i_percent = orig_i_percent * w_orig + 0.0 * w_inv
                        new_p_percent = orig_p_percent * w_orig + 1.0 * w_inv
                        
                        # Ensure ratio sum is 1
                        sum_percent = new_z_percent + new_i_percent + new_p_percent
                        if sum_percent != 0
                            new_z_percent /= sum_percent
                            new_i_percent /= sum_percent
                            new_p_percent /= sum_percent
                        else
                            # If sum is 0, set to default values
                            new_z_percent = 0.0
                            new_i_percent = 0.0
                            new_p_percent = 1.0
                        end
                    else
                        # If new total power is 0, keep original ZIP ratios
                        new_z_percent = orig_z_percent
                        new_i_percent = orig_i_percent
                        new_p_percent = orig_p_percent
                    end
                    
                    # Update load matrix
                    jpc.loadDC[idx, LOAD_PD] = new_p
                    jpc.loadDC[idx, LOADZ_PERCENT] = new_z_percent
                    jpc.loadDC[idx, LOADI_PERCENT] = new_i_percent
                    jpc.loadDC[idx, LOADP_PERCENT] = new_p_percent
                end
            end
        elseif mode == "Ps_Us"
            # Ps_Us mode: No modifications
           
        elseif mode == "Udc_Qs"
            # Udc_Qs mode: Only modify AC side reactive
            if !isnothing(ac_bus_row)
                jpc.busAC[ac_bus_row, QD] += q_ac  # QD - Reactive load (MVAr)
                # Don't modify active
            end
            
            # Process AC side load - only modify reactive
            existing_load_indices_ac = findall(x -> x == inverter.bus_ac, jpc.loadAC[:, 2])
            
            if isempty(existing_load_indices_ac)
                # If no load connected to the same node, create new load record
                new_ac_load_count += 1
                new_load_ac = zeros(1, num_cols_ac)  # Create one row
                new_load_ac[1, LOAD_I] = nld_ac + new_ac_load_count  # Load number
                new_load_ac[1, LOAD_CND] = inverter.bus_ac             # Bus number
                new_load_ac[1, LOAD_STATUS] = 1.0                         # Status (1=operational)
                new_load_ac[1, LOAD_PD] = 0.0                         # Active power (MW) - don't modify
                new_load_ac[1, LOAD_QD] = q_ac                        # Reactive power (MVAr)
                # Inverter defaults to constant power load
                new_load_ac[1, LOADZ_PERCENT] = 0.0                         # Constant impedance ratio
                new_load_ac[1, LOADI_PERCENT] = 0.0                         # Constant current ratio
                new_load_ac[1, LOADP_PERCENT] = 1.0                         # Constant power ratio
                
                # Add to new load matrix
                new_loads_ac = vcat(new_loads_ac, new_load_ac)
            else
                # If loads connected to the same node exist, update these loads
                for idx in existing_load_indices_ac
                    # Get original load power
                    orig_q = jpc.loadAC[idx, LOAD_QD]
                    
                    # Calculate new total power
                    new_q = orig_q + q_ac
                    
                    # Update load matrix - only modify reactive
                    jpc.loadAC[idx, LOAD_QD] = new_q
                    # Don't modify ZIP ratios, as they mainly relate to active power
                end
            end
        elseif mode == "Udc_Us"
            # Udc_Us mode: Don't modify AC side and DC side loads
            # No modifications
        elseif mode == "Droop_Udc_Qs"
             # Udc_Qs mode: Only modify AC side reactive
            if !isnothing(ac_bus_row)
                jpc.busAC[ac_bus_row, QD] += q_ac  # QD - Reactive load (MVAr)
                # Don't modify active
            end
            
            # Process AC side load - only modify reactive
            existing_load_indices_ac = findall(x -> x == inverter.bus_ac, jpc.loadAC[:, 2])
            
            if isempty(existing_load_indices_ac)
                # If no load connected to the same node, create new load record
                new_ac_load_count += 1
                new_load_ac = zeros(1, num_cols_ac)  # Create one row
                new_load_ac[1, LOAD_I] = nld_ac + new_ac_load_count  # Load number
                new_load_ac[1, LOAD_CND] = inverter.bus_ac             # Bus number
                new_load_ac[1, LOAD_STATUS] = 1.0                         # Status (1=operational)
                new_load_ac[1, LOAD_PD] = 0.0                         # Active power (MW) - don't modify
                new_load_ac[1, LOAD_QD] = q_ac                        # Reactive power (MVAr)
                # Inverter defaults to constant power load
                new_load_ac[1, LOADZ_PERCENT] = 0.0                         # Constant impedance ratio
                new_load_ac[1, LOADI_PERCENT] = 0.0                         # Constant current ratio
                new_load_ac[1, LOADP_PERCENT] = 1.0                         # Constant power ratio
                
                # Add to new load matrix
                new_loads_ac = vcat(new_loads_ac, new_load_ac)
            else
                # If loads connected to the same node exist, update these loads
                for idx in existing_load_indices_ac
                    # Get original load power
                    orig_q = jpc.loadAC[idx, LOAD_QD]
                    
                    # Calculate new total power
                    new_q = orig_q + q_ac
                    
                    # Update load matrix - only modify reactive
                    jpc.loadAC[idx, LOAD_QD] = new_q
                    # Don't modify ZIP ratios, as they mainly relate to active power
                end
            end
        elseif mode == "Droop_Udc_Us"
            # Droop_Udc_Us mode: Don't modify AC side and DC side loads
            # No modifications
        else
            # Unknown mode: Modify both AC side and DC side loads
            if !isnothing(ac_bus_row)
                jpc.busAC[ac_bus_row, PD] += p_ac  # PD - Active load (MW)
                jpc.busAC[ac_bus_row, QD] += q_ac  # QD - Reactive load (MVAr)
            end
            
            if !isnothing(dc_bus_row)
                jpc.busDC[dc_bus_row, PD] += p_dc  # PD - Active load (MW)
            end
            
            # Process AC side load
            existing_load_indices_ac = findall(x -> x == inverter.bus_ac, jpc.loadAC[:, 2])
            
            if isempty(existing_load_indices_ac)
                # If no load connected to the same node, create new load record
                new_ac_load_count += 1
                new_load_ac = zeros(1, num_cols_ac)  # Create one row
                new_load_ac[1, LOAD_I] = nld_ac + new_ac_load_count  # Load number
                new_load_ac[1, LOAD_CND] = inverter.bus_ac             # Bus number
                new_load_ac[1, LOAD_STATUS] = 1.0                         # Status (1=operational)
                new_load_ac[1, LOAD_PD] = p_ac                        # Active power (MW)
                new_load_ac[1, LOAD_QD] = q_ac                        # Reactive power (MVAr)
                # Inverter defaults to constant power load
                new_load_ac[1, LOADZ_PERCENT] = 0.0                         # Constant impedance ratio
                new_load_ac[1, LOADI_PERCENT] = 0.0                         # Constant current ratio
                new_load_ac[1, LOADP_PERCENT] = 1.0                         # Constant power ratio
                
                # Add to new load matrix
                new_loads_ac = vcat(new_loads_ac, new_load_ac)
            else
                # If loads connected to the same node exist, update these loads
                for idx in existing_load_indices_ac
                    # Get original load power and ZIP ratios
                    orig_p = jpc.loadAC[idx, LOAD_PD]
                    orig_q = jpc.loadAC[idx, LOAD_QD]
                    orig_z_percent = jpc.loadAC[idx, LOADZ_PERCENT]
                    orig_i_percent = jpc.loadAC[idx, LOADI_PERCENT]
                    orig_p_percent = jpc.loadAC[idx, LOADP_PERCENT]
                    
                    # Calculate new total power
                    new_p = orig_p + p_ac
                    new_q = orig_q + q_ac
                    
                    # Recalculate ZIP ratios (weighted average)
                    # Avoid division by zero
                                        if new_p != 0
                        # Original load weight
                        w_orig = abs(orig_p) / abs(new_p)
                        # Inverter load weight (default constant power)
                        w_inv = abs(p_ac) / abs(new_p)
                        
                        # Calculate new ZIP ratios
                        new_z_percent = orig_z_percent * w_orig + 0.0 * w_inv
                        new_i_percent = orig_i_percent * w_orig + 0.0 * w_inv
                        new_p_percent = orig_p_percent * w_orig + 1.0 * w_inv
                        
                        # Ensure ratio sum is 1
                        sum_percent = new_z_percent + new_i_percent + new_p_percent
                        if sum_percent != 0
                            new_z_percent /= sum_percent
                            new_i_percent /= sum_percent
                            new_p_percent /= sum_percent
                        else
                            # If sum is 0, set to default values
                            new_z_percent = 0.0
                            new_i_percent = 0.0
                            new_p_percent = 1.0
                        end
                    else
                        # If new total power is 0, keep original ZIP ratios
                        new_z_percent = orig_z_percent
                        new_i_percent = orig_i_percent
                        new_p_percent = orig_p_percent
                    end
                    
                    # Update load matrix
                    jpc.loadAC[idx, LOAD_PD] = new_p
                    jpc.loadAC[idx, LOAD_QD] = new_q
                    jpc.loadAC[idx, LOADZ_PERCENT] = new_z_percent
                    jpc.loadAC[idx, LOADI_PERCENT] = new_i_percent
                    jpc.loadAC[idx, LOADP_PERCENT] = new_p_percent
                end
            end
            
            # Process DC side load
            existing_load_indices_dc = findall(x -> x == inverter.bus_dc, jpc.loadDC[:, 2])
            
            if isempty(existing_load_indices_dc)
                # If no load connected to the same node, create new load record
                new_dc_load_count += 1
                new_load_dc = zeros(1, num_cols_dc)  # Create one row
                new_load_dc[1, LOAD_I] = nld_dc + new_dc_load_count  # Load number
                new_load_dc[1, LOAD_CND] = inverter.bus_dc             # Bus number
                new_load_dc[1, LOAD_STATUS] = 1.0                         # Status (1=operational)
                new_load_dc[1, LOAD_PD] = p_dc                        # Active power (MW)
                new_load_dc[1, LOAD_QD] = 0.0                         # Reactive power (MVAr)
                # DC system has no reactive
                # DC side defaults to constant power load
                new_load_dc[1, LOADZ_PERCENT] = 0.0                         # Constant impedance ratio
                new_load_dc[1, LOADI_PERCENT] = 0.0                         # Constant current ratio
                new_load_dc[1, LOADP_PERCENT] = 1.0                         # Constant power ratio
                
                # Add to new load matrix
                new_loads_dc = vcat(new_loads_dc, new_load_dc)
            else
                # If loads connected to the same node exist, update these loads
                for idx in existing_load_indices_dc
                    # Get original load power and ZIP ratios
                    orig_p = jpc.loadDC[idx, LOAD_PD]
                    orig_z_percent = jpc.loadDC[idx, LOADZ_PERCENT]
                    orig_i_percent = jpc.loadDC[idx, LOADI_PERCENT]
                    orig_p_percent = jpc.loadDC[idx, LOADP_PERCENT]
                    
                    # Calculate new total power
                    new_p = orig_p + p_dc
                    
                    # Recalculate ZIP ratios (weighted average)
                    # Avoid division by zero
                    if new_p != 0
                        # Original load weight
                        w_orig = abs(orig_p) / abs(new_p)
                        # Inverter load weight (default constant power)
                        w_inv = abs(p_dc) / abs(new_p)
                        
                        # Calculate new ZIP ratios
                        new_z_percent = orig_z_percent * w_orig + 0.0 * w_inv
                        new_i_percent = orig_i_percent * w_orig + 0.0 * w_inv
                        new_p_percent = orig_p_percent * w_orig + 1.0 * w_inv
                        
                        # Ensure ratio sum is 1
                        sum_percent = new_z_percent + new_i_percent + new_p_percent
                        if sum_percent != 0
                            new_z_percent /= sum_percent
                            new_i_percent /= sum_percent
                            new_p_percent /= sum_percent
                        else
                            # If sum is 0, set to default values
                            new_z_percent = 0.0
                            new_i_percent = 0.0
                            new_p_percent = 1.0
                        end
                    else
                        # If new total power is 0, keep original ZIP ratios
                        new_z_percent = orig_z_percent
                        new_i_percent = orig_i_percent
                        new_p_percent = orig_p_percent
                    end
                    
                    # Update load matrix
                    jpc.loadDC[idx, LOAD_PD] = new_p
                    jpc.loadDC[idx, LOADZ_PERCENT] = new_z_percent
                    jpc.loadDC[idx, LOADI_PERCENT] = new_i_percent
                    jpc.loadDC[idx, LOADP_PERCENT] = new_p_percent
                end
            end
        end
    end
    
    # Add new loads to JPC structure
    if !isempty(new_loads_ac)
        jpc.loadAC = vcat(jpc.loadAC, new_loads_ac)
    end
    
    if !isempty(new_loads_dc)
        jpc.loadDC = vcat(jpc.loadDC, new_loads_dc)
    end

    # Store converter data in JPC structure
    jpc.converter = converters
    
    return jpc
end

                


