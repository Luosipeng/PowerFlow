# Helper function to assign bus data for in-service and load-connected buses
function assign_bus_data(bus_data::DataFrame, 
    load_data::DataFrame, 
    gen_data::DataFrame, 
    utility_data::DataFrame
    )
#Call bus indexing function
(PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, AREA, VM,
VA, BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN)=PowerFlow.idx_bus()
(EquipmentID,Voltage,Initial_Voltage,In_Service,Bus_Type)=PowerFlow.bus_idx()#节点母线索引
(load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent)=PowerFlow.load_idx()#负荷索引

# Find in-service buses
inservice = findall(bus_data[:, In_Service] .== "Yes")
bus = zeros(length(inservice), 13)
bus[:, BUS_I] .= 1:length(inservice)  # Assign new ID for all buses

# Identify and assign PQ buses (type 1)
PQindex = findall(bus_data[:, Bus_Type] .== 0)
bus[PQindex, TYPE] .= 1

# Filter in-service load data
Load_inservice = findall(load_data[:, load_inservice] .== "Yes")
load_data = load_data[Load_inservice, :]

# Create a dictionary to map EquipmentID to bus index
bus_index = collect(1:size(bus_data[inservice, :], 1))
dict_bus = Dict(zip(bus_data[inservice, EquipmentID], bus_index))

# Assign PV buses (type 2)
assign_pv_buses(bus, gen_data, dict_bus)

# Assign Slack buses (type 3)
assign_slack_buses(bus, utility_data, dict_bus)

# Assign load data to buses
assign_load_data(bus, load_data, dict_bus)

# Set voltage values and zone information
bus[:, VM] .= 1.0  # Voltage magnitude
bus[:, VA] .= 0    # Voltage angle
bus[:, BASEKV] .= bus_data[inservice, Voltage] .* parse.(Float64, bus_data[inservice, Initial_Voltage]) ./ 100
bus[:, ZONE] .= 1  # Zone set to 1 for all buses

# Set maximum and minimum voltage limits
bus[:, VMAX] .= 1.05
bus[:, VMIN] .= 0.8

return bus,dict_bus
end

# Function to assign PV buses (type 2) based on generator 
function assign_pv_buses(bus, gen_data, dict_bus)
#Call bus indexing function
(Gen_connected_element,Gen_inservice,Gen_controlmode,
Gen_power_rating,Gen_apparent_power_rating,Gen_voltage)=gen_idx() #发电机索引
(PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, AREA, VM,
VA, BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN)=idx_bus()


# Assign PV buses for generators
geninservice = findall(gen_data[:, Gen_inservice] .== "Yes")
gen_data = gen_data[geninservice, :]
pv_index = findall(gen_data[:, Gen_controlmode] .== "Voltage Control")
pv_bus = map(k -> dict_bus[k], gen_data[pv_index, Gen_connected_element])
bus[pv_bus, TYPE] .= 2

end

# Function to assign Slack buses (type 3) based on utility data
function assign_slack_buses(bus, utility_data, dict_bus)
#Call bus indexing function
(Utility_EquipmentID,Utility_connected_ID,Utility_Inservice,Utility_Voltage,Utility_control_mode)=utility_idx()#电网索引
(PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, AREA, VM,
VA, BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN)=idx_bus()

slack_index = findall(utility_data[:, Utility_control_mode] .== "Swing")
slack_bus = map(k -> dict_bus[k], utility_data[slack_index, Utility_connected_ID])
bus[slack_bus, TYPE] .= 3
end

# Function to assign load data to buses
function assign_load_data(bus, load_data, dict_bus)
#Call bus indexing function
(PQ, PV, REF, NONE, BUS_I, TYPE, PD, QD, GS, BS, AREA, VM,
VA, BASEKV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN)=idx_bus()
(load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent)=load_idx()#负荷索引

load_connected_bus = map(k -> dict_bus[k], load_data[:, ConectedID])  # Searching the connected bus ID
bus[load_connected_bus, PD] .= 0.001 .* load_data[:, load_kva] .* parse.(Float64, load_data[:, load_pf]) ./ 100
bus[load_connected_bus, QD] .= 0.001 .* load_data[:, load_kva] .* sin.(acos.(parse.(Float64, load_data[:, load_pf]) ./ 100))
# if Ci !== nothing
#     inverter_connected_bus = map(k -> dict_bus[k], Ci)
#     bus[inverter_connected_bus, PD] .= bus[inverter_connected_bus, PD].-P_inv./1000
#     bus[inverter_connected_bus, QD] .= bus[inverter_connected_bus, QD].-Q_inv./1000
# end
end