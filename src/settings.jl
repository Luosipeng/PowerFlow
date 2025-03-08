"""
    Settings function for the power flow calculation, including the following parts
    - power flow options
    - OPF options
    - output options
    - other options
    - MINOPF options
"""

function options(; kwargs...)
    # Define the default options vector
    PF = Dict(
        # Power flow options
        "PF_ALG" => "NR",
        "PF_TOL" => 1e-8,
        "PF_MAX_IT" => 10,
        "PF_MAX_IT_FD" => 30,
        "PF_MAX_IT_GS" => 1000,
        "ENFORCE_Q_LIMS" => 0,
        "PF_DC" => 0,
        "DC" => 0,
        "DC_PREPROCESS" => 0,
        "NR_ALG" => "gmres",
    )
    OPF = Dict(
        # Optimal power flow options
        "OPF_ALG" => 0,
        "OPF_VIOLATION" => 5e-6,
        "CONSTR_TOL_X" => 1e-4,
        "CONSTR_TOL_F" => 1e-4,
        "CONSTR_MAX_IT" => 150,
        "OPF_FLOW_LIM" => 0,
        "OPF_IGNORE_ANG_LIM" => 0,
        "OPF_ALG_POLY" => 0,
        "OPF_POLY2PT" => 0,
    ) 
    OUTPUT = Dict(
        # Output options
        "VERBOSE" => 1,
        "OUT_ALL" => -1,
        "OUT_SYS_SUM" => 1,
        "OUT_AREA_SUM" => 0,
        "OUT_BUS" => 1,
        "OUT_BRANCH" => 1,
        "OUT_GEN" => 1,
        "OUT_ALL_LIM" => 1,
        "OUT_V_LIM" => 1,
        "OUT_LINE_LIM" => 1,
        "OUT_PG_LIM" => 1,
        "OUT_QG_LIM" => 1,
        "OUT_RAW" => 0,
    )
    default_options = Dict(
        "PF" => PF,
        "OPF" => OPF,
        "OUTPUT" => OUTPUT,
    )
    # Update the default options with provided key-value pairs
    options = deepcopy(default_options)
    for (key, value) in kwargs
        if haskey(options, key)
            options[key] = value
        else
            println("Warning: Option $key is not recognized and will be ignored.")
        end
    end

    return options
end

