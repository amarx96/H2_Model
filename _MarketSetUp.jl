
# Define the struct
using Revise



struct MarketData
    consumers::Vector{String}
    producers::Vector{String}
    ports::Vector{String}
    producers_ports::Vector{String}
    producers_markets::Vector{String}
    consumers_ports::Vector{String}
    suppliers::Vector{String}
    nodes::Vector{String}
    nodes_markets::Vector{String}
    sectors::Vector{String}
    subsectors::Vector{String}
    industries::Vector{String}
    industries_ports::Vector{String}
    goods::Vector{String}
    fuels::Vector{String}
    endo_fuels::Vector{String}
    exo_fuels::Vector{String}
    traded_fuels::Vector{String}
    non_traded_fuels::Vector{String}
    processes::Vector{String}
    years::Vector{Int64}
    modes::Vector{String}
    DiscountRate::Float64
    adj::Dict{String, Dict{String, Dict{String, Float64}}}
end

# Function to set up the market
"""
    market_setup(;
        consumers=nothing, producers=nothing, ports=nothing, 
        nodes=nothing,fuels=nothing,
        years=nothing,pFm=pFm, pip_adj=pip_adj,shp_adj=shp_adj,sub_adj=sub_adj)


    market_setup(consumers=nothing, producers=nothing, ports=nothing, nodes=nothing,goods=nothing)

TBW
"""
function market_setup(;
        consumers=nothing, producers=nothing, ports=nothing, 
        nodes=nothing,fuels=nothing,
        years=nothing,pFm=pFm, pip_adj=pip_adj,shp_adj=shp_adj,sub_adj=sub_adj)
    # Set default values
    consumers = consumers === nothing ? ["Steel"] : consumers
    producers = producers === nothing ? ["Producer"] : producers
    ports = ports === nothing ? ["Antofagasta", "Rotterdam"] : ports
    fuels = fuels === nothing ? vcat(unique([k[1] for k in keys(pFm)]), "na") : fuels
    years = years === nothing ? [2030] : years
    nodes = nodes === nothing ? nodes = ["Antofagasta", "Chanaral", "Rotterdam", "Duisburg"] : nodes



    # Define other variables
    sector = ["Industry", "Transport", "Shipping", "Aviation"]
    subsector = ["Industry", "Shipping", "Aviation"]
    goods = ["Steel", "Fertilizer", "Aromatics/Olefins", "Shipping", "Aviation"]
    #fuels = ["H2", "NH3", "Gas", "Coal", "Electricity", "MGO", "Biodiesel", "LNG", "MeOH", "Naphtha","CO2","CO","N","Biomass","LCH2","HCH2", "HCNH3", "LCNH3", "LCMeOH"]
    processes = unique([k[2] for k in keys(pFm)])
    fuels = unique([k[1] for k in keys(pFm)])
    exo_fuels = filter(x -> !(x in ["N","H2", "NH3", "MeOH", "HCH2","LH2", "LCH2","HCNH3", "LCNH3", "BMeOH", "LCMeOH", "E-Kerosene", "FT","LCFT" , "CO2"]), fuels)
    endo_fuels = filter(x -> !(x in exo_fuels), fuels)
    traded_fuels = ["H2", "NH3","MeOH", "LCNH3", "LCMeOH", "LCH2", "LH2"]
    non_traded_fuels = filter(x -> !(x in traded_fuels), fuels)
    modes = ["pipeline", "shipping","submarine"]
    
    DiscountRate = 0.12

    suppliers = vcat(producers,ports)
    producers_market = vcat(producers, ["Market"])
    nodes_markets = vcat(nodes, ["Local"])

    pipDict = Dict(
        row.Column1 => Dict(l => row[Symbol(l)] for l in nodes) for row in eachrow(pip_adj)
    )
    
    subDict = Dict(
        row.Column1 => Dict(l => row[Symbol(l)] for l in nodes) for row in eachrow(sub_adj)
    )
    
    shpDict = Dict(
        row.Column1 => Dict(l => row[Symbol(l)] for l in nodes) for row in eachrow(shp_adj)
    )
        # Function to add entries to the combined dictionary for Adjacency and Distance Matrices
    adj = Dict{String, Dict{String, Dict{String, Float64}}}()
    function add_to_combined(fromDict, mode)
        for (origin, destinations) in fromDict
            # Check if the origin key already exists in the combined dictionary
            if !haskey(adj, origin)
                adj[origin] = Dict{String, Dict{String, Float64}}()
            end
            # Loop through each destination and assign values under the respective mode
            for (destination, value) in destinations
                if !haskey(adj[origin], destination)
                    adj[origin][destination] = Dict{String, Float64}()
                end
                adj[origin][destination][mode] = value
                if origin==destination
                end
            end
        end
    end

    add_to_combined(pipDict, "pipeline")
    add_to_combined(shpDict, "shipping")
    add_to_combined(subDict, "submarine")


    function adjust_nested_dict(dict::Dict{String, Dict{String, Dict{String, Float64}}})
        for node in keys(adj)
            for destination in keys(adj[node])
                for mode in keys(adj[node][destination])
                    if node == destination && mode == "pipeline"
                        adj[node][destination][mode] = 1
                    end
                end
            end
        end
        return dict
    end
    
    adj = adjust_nested_dict(adj)

    return MarketData(
        consumers, 
        producers, 
        ports, 
        vcat(producers, ["Port"]),
        producers_market, 
        vcat(consumers, ["Port"]), 
        suppliers,
        nodes, 
        nodes_markets,
        sector,
        subsector,
        vcat(consumers, producers),
        vcat(vcat(consumers, producers), ["Port"]),
        goods,
        fuels,
        endo_fuels,
        exo_fuels,
        traded_fuels,
        non_traded_fuels,
        processes,
        years,
        modes,
        DiscountRate,
        adj
    )
end

