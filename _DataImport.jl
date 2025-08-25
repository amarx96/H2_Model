# Data Imports
function ensure_imported(packages::Vector{Symbol})
    for pkg in packages
        if !isdefined(Main, pkg)
            @eval using $pkg
        end
    end
end

# Check and import the necessary packages
ensure_imported([:CSV, :DataFrames, :DataStructures])

# Helper functions
readcsv(x; dir=@__DIR__) = CSV.read(joinpath(dir, x), DataFrame, stringtype=String)
readin(x::AbstractDataFrame; default=0,dims=1) = DefaultDict(default, Dict((dims > 1 ? Tuple(row[y] for y in 1:dims) : row[1]) => row[dims+1] for row in eachrow(x)))

function import_data()
    data_dir = joinpath(@__DIR__, "data")

    #### Process Industry Mapping
    df = readcsv("_processIndustryMap.csv", dir=data_dir)
    pIm = Dict{Tuple{String, String}, Int}()
    
    for row in eachrow(df)
        for col in names(df)[2:end]
            pIm[(col, row[:Process])] = row[col]
        end
    end

        #### Process Industry Mapping
        df = readcsv("_processIndustryMap.csv", dir=data_dir)
        pIm = Dict{Tuple{String, String}, Int}()
        
        for row in eachrow(df)
            for col in names(df)[2:end]
                pIm[(col, row[:Process])] = row[col]
            end
        end


    #### Process Fuels Mapping
    df = readcsv("_FuelProcessMap.csv", dir=data_dir)
    processes = names(df)[2:end]
    fuels = Array{String,1}(df[1:end,1])
    
    df = df[:,2:end]
    pFm = Dict{Tuple{String, String}, Int}()
        
    for (i, fuel) in enumerate(fuels)
            for (j, process) in enumerate(processes)
                key = (fuel, process)
                value = df[i, j]
                pFm[key] = value
            end
    end

    #### Industry location Mapping
    iNm = readcsv("_industryLocationMap.csv", dir=data_dir)
    iNm = Dict((iNm[i, :Location], iNm[i, :Industry]) => iNm[i, :Value] for i in 1:nrow(iNm))
    iNm["Local", "Market"] = 1

    iLm = readcsv("_IndustryLevelMap.csv", dir=data_dir)
    iLm = Dict((iLm[i, :Industry]) => iLm[i, :Level] for i in 1:nrow(iLm))

    #### Output goods
    finalGoodProcessMap = readcsv("_processOutput.csv", dir=data_dir)
    finalGoodProcessMap = Dict(finalGoodProcessMap[i, :Process] => finalGoodProcessMap[i, :Output] for i in 1:nrow(finalGoodProcessMap))

    IOM = readcsv("_IndustryOutputMapping.csv", dir=data_dir)
    IOM = Dict((IOM[i, :Industry],IOM[i, :Output]) => IOM[i, :Value] for i in 1:nrow(IOM))

    #### Renewable Fuel Mapping
    rFm = readin(readcsv("_rfnboFuelMap.csv", dir=data_dir), dims=3)

    #### Fuels
    FuelUse = readin(readcsv("_fuelIndustryMapping.csv", dir=data_dir), dims=2)

    #### Price Paths
    P = readcsv("_price_path.csv", dir=data_dir)
    #P[!,"Value"] = replace.(P[:,"Value"], "," => ".")
    #P[!,"Value"] = parse.(Float64, P[:,"Value"])
    P = Dict((P[i, :Fuel],P[i, :Location], P[i, :Year]) => P[i, :Value] for i in 1:nrow(P))

    #### Output Ratios
    sO = dropmissing(readcsv("_outputRatio.csv", dir=data_dir), :Value)
   # sO[!,"Value"] = replace.(sO[:,"Value"], "," => ".")
    #sO[!,"Value"] = parse.(Float64, sO[:,"Value"])
   
    sO = Dict((sO[i, :Process],sO[i, :Output]) => sO[i, :Value] for i in 1:nrow(sO))##

    #### Input Ratios
    sI = dropmissing!(readcsv("_inputRatio.csv", dir=data_dir))

    outputs = unique(sI.Output)
    processes = unique(sI.Process)
    fuels = unique(sI.Input)


    sI = Dict((sI[i, :Process],sI[i, :Input],sI[i, :Output],sI[i, :Year]) => sI[i, :Value] for i in 1:nrow(sI))##


    ### sIm: 
    sIm = readcsv("_sectorIndustryMapping.csv",dir=data_dir)
    sIm = Dict((sIm[i, :Sector],sIm[i, :Industry] )  => sIm[i, :Value] for i in 1:nrow(sIm))
  
    #### Supplier Fuel Map
    sFm = readcsv("_supplierFuelMap.csv", dir=data_dir)
    sFm = Dict((sFm[i, :Supplier], sFm[i, :Fuel])  => sFm[i, :Value] for i in 1:nrow(sFm))
    

    #### Capacity Costs
   K=  readin(readcsv("_capex.csv",dir=data_dir),dims=2,default=10)
   # K = Dict((K[i, :process], K[i, :year]) => K[i, :Value] for i in 1:nrow(K))
   # K[!,"Value"] = replace.(K[:,"Value"], "," => ".")
   # K[!,"Value"] = parse.(Float64, K[:,"Value"])
   # K = Dict((K[i, :process], K[i, :year]) => K[i, :Value] for i in 1:nrow(K))

    # Import Prices
    pImports = readin(readcsv("_importPrices.csv", dir=data_dir),dims=3)
    importGoods = unique(readcsv("_importPrices.csv", dir=data_dir).Process)

    #### Residual Capacity
    ResCap = readin(readcsv("_residual_capacity.csv", dir=data_dir), dims=4,default=0)

    #### Residual Capacity
    Opex = readin(readcsv("_opex.csv", dir=data_dir), dims=2)

    ### Fix Costs and Maintance 
    # Processes
    FOM = readin(readcsv("_FOM.csv", dir=data_dir), dims=2,default=0)

    ## Fix Costs and Maintance 
    ExportFOM = readin(readcsv("_TransportFOM.csv", dir=data_dir), dims=3)


#    Opex = readcsv("_opex.csv", dir=data_dir)
#    Opex[!,"Value"] = replace.(Opex[:,"Value"],"," =>".")
#    Opex[!,"Value"] = parse.(Float64,Opex[:,"Value"])
#    Opex = readin(Opex; default=0, dims=4)

    ### Capacity factor
    ### Restrict capacity by capacity factors
    cF =  readin(readcsv("_capacity_factor.csv",dir=data_dir),dims=2,default=1)


    ### Export Capacity
    ExportK =  readin(readcsv("_TransportCapex.csv",dir=data_dir),dims=3,default=1)


    #### RFNBOS
    R = readin(readcsv("_rfnbo_quotas.csv", dir=data_dir),dims=2)
    #R[!,"value"] = parse.(Float64, R[:,"value"])
    #R = Dict((R[i, :target], R[i, :year]) => R[i, :value] for i in 1:nrow(R))

    #### Emission factorsr
    eF =  readcsv("_emissions.csv",dir=data_dir)
    #eF[!,"Value"] = replace.(eF[:,"Value"],"," =>".")
    #eF[!,"Value"] = parse.(Float64,eF[:,"Value"])
    eF = DefaultDict(0.0, Dict((eF[i,:Process], eF[i,:Output]) => eF[i, :Value] for i in 1:nrow(eF))) 

    # Emission Allowances 
    eA =  readcsv("_e_benchmark.csv",dir=data_dir)
    eA[!,"Value"] = replace.(eA[:,"Value"],"," =>".")
    eA[!,"Value"] = parse.(Float64,eA[:,"Value"])
    eA = Dict((eA[i,:Process], eA[i,:Year]) => eA[i, :Value] for i in 1:nrow(eA))

    # Carbon Price
    CO2Price =  readin(readcsv("_CO2Price.csv",dir=data_dir),dims=1)
    #### Demand
    D = readin(readcsv("_demand.csv", dir=data_dir), dims=4)

    #### Fuel Switching
    sFuelSwitching = readin(readcsv("_fuelSwitching.csv", dir=data_dir), dims=2)

    # Import technology Lifetime
    TechnologyLifetime = readin(readcsv("_technology_lifetime.csv",dir=data_dir),dims=1)

    ExportLifeTime = readin(readcsv("_ExportLifeTime.csv",dir=data_dir),dims=2)

    # TransportFuelMap 
    transportFuelMap = readin(readcsv("_FuelTransportMap.csv",dir=data_dir),dims=2)

    # Import Pipeline & Shipping
    pip_adj = readcsv("_pipeline_distance_matrix.csv",dir=data_dir)
    shp_adj = readcsv("_shipping_distance_matrix.csv",dir=data_dir)
    sub_adj = readcsv("_submarine_pipeline_distance_matrix.csv",dir=data_dir)

 

    #### Transport Costs
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
            end
        end
    end

    # Transport 
    transportLosses =  readcsv("_transport_losses.csv",dir=data_dir)
    transportLosses = Dict((transportLosses[i,:Commodity],transportLosses[i, :Mode]) => transportLosses[i, :Losses] for i in 1:nrow(transportLosses))



    # Return all objects created
    return IOM,iLm,pIm,pFm, iNm, finalGoodProcessMap, rFm, FuelUse, P, sO, sI, sFm, K,ExportK, ResCap,Opex, R, D, sFuelSwitching, TechnologyLifetime,ExportLifeTime,sIm,eF,eA,pip_adj,shp_adj,sub_adj,transportLosses, transportFuelMap,pImports,importGoods,CO2Price, outputs,processes,fuels,cF,FOM,ExportFOM
end

IOM,iLm,pIm,pFm, iNm, finalGoodProcessMap, rFm, FuelUse, P, sO, sI, sFm, K,ExportK, ResCap,Opex, R, D, sFuelSwitching, TechnologyLifetime,ExportLifeTime,sIm,eF,eA,pip_adj,shp_adj,sub_adj,transportLosses, transportFuelMap,pImports,importGoods,CO2Price, outputs,processes,fuels,cF,FOM,ExportFOM = import_data()