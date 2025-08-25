############################ Integrated
using CSV
using DataFrames
using DataStructures
using HiGHS
using JuMP
using Plots
using Plots.Measures
using Statistics
using StatsPlots


include(joinpath(@__DIR__, "helper_functions.jl")) #

# helper functions
# readin function for parameters; this makes handling easier
readcsv(x; dir=@__DIR__) = CSV.read(joinpath(dir, x), DataFrame, stringtype=String) 
readin(x::AbstractDataFrame; default=0,dims=1) = DefaultDict(default,Dict((dims > 1 ? Tuple(row[y] for y in 1:dims) : row[1]) => row[dims+1] for row in eachrow(x)))


data_dir = joinpath(@__DIR__,"_data")

############ Controlling and Structuring Elements
#### Process Fuels  Mapping
df = readcsv("_FuelProcessMap.csv",dir=data_dir)
processes = names(df)[2:end]
fuels = Array{String,1}(df[1:end,1])

df = df[:,2:end]
#df = parse.(Int64,df = df[:,2:end])
pFm = Dict{Tuple{String, String}, Int}()

for (i, fuel) in enumerate(fuels)
    for (j, process) in enumerate(processes)
        key = (fuel, process)   # Create a tuple key as (Fuel, Process)
        value = df[i, j]        # Extract the corresponding value from the DataFrame and saves it in a Dict
        pFm[key] = value
    end
end
# Correct Methanol
pFm["CO2", "MeOHSyn1"]=0
pFm["CO", "MeOHSyn1"]=1

pFm["CO2", "MeOHSyn2"]=1
pFm["CO", "MeOHSyn2"]=0


#### Process Industry  Mapping
df = readcsv("_processIndustryMap.csv",dir=data_dir)
pIm = Dict{Tuple{String, String}, Int}()
for row in eachrow(df)
    for col in names(df)[2:end]  # Skip the first column (Process)
        pIm[(col, row[:Process])] = row[col]
    end
end

pIm["Fertilizer", "Fertilizer Synthesis"]
pIm["MeOH Producer", "MeOHSyn1"]

#### Industry location Mapping
iLm = readcsv("_industryLocationMap.csv",dir=data_dir)
iLm = Dict((iLm[i,:Location],iLm[i,:Industry])  => iLm[i, :value] for i in 1:nrow(iLm))


# Output goods
processOutput = readcsv("_processOutput.csv",dir=data_dir)
processOutput = Dict(processOutput[i,:Process] => processOutput[i, :Output] for i in 1:nrow(processOutput))

processOutput["Mto/Mta"]

# Renewable Fuel Mapping
rFm = readin("rfnboFuelMap.csv",dir=data_dir,dims=1)

# Fuels
FuelUse = readin("_fuelUse.csv",dir=data_dir,dims=2)
EndoFuels =  readin("_fuelEndo.csv", dims=1, dir=data_dir)


# Price Paths 
P =  readcsv("_price_path.csv",dir=data_dir)
P[!,"Value"] = replace.(P[:,"Value"],"," =>".")
P[!,"Value"] = parse.(Float64,P[:,"Value"])
P = Dict((P[i,:Fuel],P[i, :Year]) => P[i, :Value] for i in 1:nrow(P))

# Production ratios
# Output Ratio
sO =  readcsv("_outputRatio.csv",dir=data_dir)
sO[!,"Value"] = replace.(sO[:,"Value"],"," =>".")
sO[!,"Value"] = parse.(Float64,sO[:,"Value"])
sO = Dict((sO[i,:Industry],sO[i, :Process],sO[i, :Output],sO[i, :Year]) => sO[i, :Value] for i in 1:nrow(sO))

# Input ratios
sI =  readcsv("_inputRatio.csv",dir=data_dir)
dropmissing!(sI)
sI[!,"Value"] = replace.(sI[:,"Value"],"," =>".")
sI[!,"Value"] = parse.(Float64,sI[:,"Value"])
sI = Dict((sI[i, :Process],sI[i, :Input],sI[i, :Year]) => sI[i, :Value] for i in 1:nrow(sI))


# Supplier Fuel Map 
sFm = readin("_supplierFuelMap.csv",dims=2,dir=data_dir)

# Capacity costs
K =  readcsv("_capex.csv",dir=data_dir)
K[!,"Value"] = replace.(K[:,"Other_Value"],"," =>".")
K[!,"Value"] = parse.(Float64,K[:,"Value"])
K = Dict((K[i, :process],K[i, :year]) => K[i, :Value] for i in 1:nrow(K))

# Residual Capacity
ResCap = readin("_residual_capacity.csv",dims=3,dir=data_dir)



# RFNBOS
R =  readcsv("_rfnbo.csv",dir=data_dir)
R[!,"value"] = replace.(R[:,"value"],"," =>".")
R[!,"value"] = parse.(Float64,R[:,"value"])
R = Dict((R[i,:target],R[i, :year]) => R[i, :value] for i in 1:nrow(R))


# Demand
Q =  readin("_demand.csv",dims=4,dir=data_dir)
#Q[!,"Value"] = replace.(Q[:,"Demand"],"," =>".")
#Q[!,"Value"] = parse.(Float64,Q[:,"Value"])

#Q = Dict((Q[i,:Subsector],Q[i, :Process],Q[i, :Location_short],Q[i, :Year]) => Q[i, :Demand] for i in 1:nrow(Q))


sFuelSwitching = readin("_sFuelSwitching.csv",dir=data_dir,dims=3)


# Markets & locations
consumers = readcsv("consumers.csv",dir=data_dir).Industry
sectors = readcsv("consumers.csv",dir=data_dir).Sector


BIG = 1e6
locations = unique(readcsv("_industryLocationMap.csv",dir=data_dir).Location)
sectors = ["Industry"]

ports = ["Antofagasta", "Rotterdam", "Hamburg", "Agadir"]



consumers = ["Fertilizer", "Steel", "Hvc"]
suppliers = ["H2 Producer", "NH3 Producer", "MeOH Producer"]


industries = vcat(consumers,producer)


goods = ["Fertilizer","Steel", "Olefins/Aromatics", "Shipping"]
processes = ["Bof", "Dri", "Smr", "Hb", "Fertilizer Synthesis", "Conventional ICE", "H2 ICE",
"NH3 ICE", "LNG ICE", "MeOH ICE", "Mto/Mta", "Nto/Nta","Rwgs","MeOHSyn1","MeOHSyn2","Asu", "Btm","Dac","El", "Pv", "Onwind"]
fuels = ["H2", "NH3", "Gas", "Coal", "Electricity", "MGO", "Biodiesel", "LNG", "MeOH", "Naphtha","CO2","CO","Biomass", "N"]
purchased_fuel = filter(x -> !(x in ["N", "CO", "CO2"]), fuels)
years = [2030,2035,2040,2045,2050]

gIm = readin("_goodsIndustries.csv",dir=data_dir,dims=1)


locations  = ["Chanaral", "Ludwigshafen","Duisburg" ,"Laayoune", "Hamburg","Antofagasta","Agadir", "Leverkusen"]


DiscountRate = 0.12
######################################################### Initialize Model
m = Model(HiGHS.Optimizer)

@variable(m,qProcess[i in industries,ρ in processes, l in locations, y in years; haskey(iLm,(l,i)) && pIm[i,ρ]==1]>=0
)


@variable(m,qProcessFuelDemand[i in industries,ρ in processes,f in fuels, l in locations, y in years;haskey(iLm,(l,i)) && pIm[i,ρ]==1 && pFm[f,ρ]==1 && haskey(sI,(ρ,f,y))]>=0
)

@variable(m,qFuelPurchased[i in industries, f in fuels,l in locations,years;any(haskey(sI, (ρ,f,y)) for  ρ in processes, y in years)  && haskey(iLm,(l,i)) && FuelUse[f,i]==1]>=0)

# Demand Constraint
@constraint(m, DemandConstraint[i in industries,g in goods, l in locations, y in years, haskey(Q,(i,g,l,y)) && haskey(iLm,(l,i))],
            Q[i,g,l,y] == sum(qProcess[i,ρ,l,y] for ρ in processes if pIm[i,ρ]==1 && haskey(processOutput, ρ) && processOutput[ρ]==g &&  haskey(iLm,(l,i)))
            )

# Fuel Inventory Constraint for Fuel Demand Self Production 
@constraint(m, FuelInventoryConstraint[i in industries, f in fuels, l in locations, y in years; FuelUse[f,i]==1 && haskey(iLm,(l,i))],
    sum(qProcessFuelDemand[i, ρ, f, l, y] for ρ in processes if pIm[i,ρ]==1 && pFm[f,ρ]==1) <= 
        qFuelPurchased[i, f, l, y]  + sum(sO[i, ρρ, f, y] * qProcess[i, ρρ, l, y]  for ρρ in processes if haskey(sO, (i, ρρ, f, y)) && pIm[i,ρρ]==1)
        )


#Set PurchasedFuels to 0 for 
#non_traded_fuels =  ["NH3", "H2"]
#suppliers
#@constraint(m, ZeroPurchaseConstraint1[s in suppliers, f in non_traded_fuels, l in locations,y in years; FuelUse[f,s]==1 && haskey(iLm,(l,s))],
#                )
non_traded_fuels =  ["CO", "CO2", "N"]
@constraint(m, ZeroPurchaseConstraint2[i in industries, f in non_traded_fuels, l in locations,y in years;  any(haskey(sI, (ρ,f,y)) for  ρ in processes, y in years)  && haskey(iLm,(l,i)) && FuelUse[f,i]==1],
                                    qFuelPurchased[i, f, l, y] == 0
                )

# Single Input Constraint
@constraint(m, InputConstraint[i in industries, ρ in processes,f in fuels,l in locations, y in years; haskey(iLm,(l,i)) && haskey(sI,(ρ,f,y)) && pFm[f,ρ]==1 && !haskey(sFuelSwitching,(i,ρ,f)) && pIm[i,ρ]==1],
    qProcess[i,ρ,l,y] * sI[ρ,f,y] ==  qProcessFuelDemand[i,ρ,f,l,y]) 


# Fuel Switching
@constraint(m, FuelSwitchingConstraint[i in industries, ρ in processes,l in locations, y in years; any(haskey(sFuelSwitching,(i,ρ,f)) for f in fuels) && haskey(iLm,(l,i))],
            qProcess[i,ρ,l,y] <= sum(sFuelSwitching[i,ρ,f] * qProcessFuelDemand[i,ρ,f,l,y] for f in fuels if haskey(sFuelSwitching,(i,ρ,f)))
            )

# calculate the total installed capacity in each year
TechnologyLifetime = readin("_technology_lifetime.csv",dir=data_dir,dims=1)
@variable(m, NewCapacity[i in industries,ρ in processes,l in locations, y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))]>=0)

@variable(m, AccumulatedCapacity[i in industries,ρ in processes,l in locations, y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))]>=0)

@constraint(m, CapacityAccountingFunction[i in industries,ρ in processes, l in locations,y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))],
    sum(NewCapacity[i,ρ,l,yy] for yy in years if yy<=y && y - yy <= TechnologyLifetime[ρ]) + ResCap[ρ,"GER",y] == AccumulatedCapacity[i,ρ,l,y]
)

############ Duals: Capacity Constraint μCap
@constraint(m, CapacityConstraint[i in industries,ρ in processes,l in locations, y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))],
                    qProcess[i,ρ,l,y]  <= AccumulatedCapacity[i,ρ, l,y])# Bestimmt Capacity

############ Duals: RFNBO Constraint for non Industry
sIm = readin("_sectorIndustryMapping.csv",dims=3,dir=data_dir)
@constraint(m, RfnboConstraint1[s in sectors,ss in sectors, y in years],
 R[s,y] * sum(qProcessFuelDemand[c, ρ, f, l, y] for f in fuels,ρ in processes, c in consumers, l in locations if haskey(qProcessFuelDemand, (c,ρ,f,l,y)) && haskey(iLm,(l,c)) && f∉["Electricity", "CO2", "CO"] && haskey(sIm, (s,ss,c)))
  <=  sum(qProcessFuelDemand[c, ρ, f, l, y] for f in fuels,ρ in processes, c in consumers,  l in locations if haskey(qProcessFuelDemand, (c,ρ,f,l,y)) && haskey(iLm,(l,c)) && rFm[f] == 1 && haskey(sIm, (s,ss,c))))

# Emission factor
eF =  readcsv("_emissions.csv",dir=data_dir)
eF[!,"Value"] = replace.(eF[:,"Value"],"," =>".")
eF[!,"Value"] = parse.(Float64,eF[:,"Value"])
eF = Dict((eF[i,:Process]) => eF[i, :Value] for i in 1:nrow(eF))

############ Emission constraint
@variable(m,qCO2[c in consumers,l in locations,years; haskey(iLm, (l,c))]>=0)
@constraint(m, EmissionConstraint5[c in consumers,l in locations, y in years; haskey(iLm,(l,c))],
                sum(eF[ρ] * qProcess[c,ρ,l,y] for ρ in processes if haskey(eF,ρ) && pIm[c,ρ]==1) <= qCO2[c,l,y])

##################### Production of Hydrogen and Derivaives ##################### 
# qFuelPurchased: Locally purchased fuel
# qFuelSold: Locally sold fuel
suppliers_port = ["H2 Producer","NH3 Producer","MeOH Producer", "Port"]

### Restrict Grid Access for hydrogen suppliers
@constraint(m, GridAccessRestriction[s in  suppliers,l in locations, y in years; haskey(iLm,(l,s))],
                        qFuelPurchased[s,"Electricity",l,y]==0)

### Restrict capacity by capacity factors
cF =  readcsv("_producer_cf.csv",dir=data_dir)
dropmissing!(cF)
cF[!,"Value"] = replace.(cF[:,"value"],"," =>".")
cF[!,"Value"] = parse.(Float64,cF[:,"Value"])
cF = Dict((cF[i,:process], cF[i,:location]) => cF[i, :Value] for i in 1:nrow(cF))

@constraint(m, CapacityFactorRestriction[s in  suppliers, ρ in processes, l in locations, y in years; haskey(iLm,(l,s)) && pIm[s,ρ]==1 && haskey(cF, (ρ,l))],
                    qProcess[s,ρ,l,y]  <= cF[ρ,l] * AccumulatedCapacity[s,ρ, l,y])

### Export Constraints 
##################### Prepare Shipping data
consumers_ports = vcat(consumers, ["Port"])
suppliers_ports = vcat(suppliers, ["Port"])
modes = ["pipeline", "shipping"]
traded_fuels = ["H2", "NH3", "MeOH"]
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

pip_adj = readcsv("Pipeline_distance_matrix.csv",dir=data_dir)
pipDict = Dict(
    row.Column1 => Dict(l => row[Symbol(l)] for l in locations) for row in eachrow(pip_adj)
)

shpDict = readcsv("Shipping_distance_matrix.csv",dir=data_dir)
shpDict = Dict(
    row.Column1 => Dict(l => row[Symbol(l)] for l in locations) for row in eachrow(shpDict)
)

pip_adj = readcsv("Pipeline_distance_matrix.csv",dir=data_dir)
pipDict = Dict(
    row.Column1 => Dict(l => row[Symbol(l)] for l in locations) for row in eachrow(pip_adj)
)

add_to_combined(pipDict, "pipeline")
add_to_combined(shpDict, "shipping")


@variable(m,qFuelSold[s in  suppliers,c in consumers,f in traded_fuels,l in locations,ll in locations,y in years;
                (haskey(iLm,(l,s))) && haskey(iLm,(ll,c)) && sFm[s,f]==1]>=0)

                
@variable(m, qFuelExports[s in suppliers_ports, c in consumers_ports, f in traded_fuels, l in locations, ll in locations, mode in modes, y in years;
    haskey(iLm, (l, s)) && haskey(iLm, (ll, c)) && (adj[l][ll][mode]>0)  && sFm[s,f]==1] >= 0)                                                                   


@variable(m,qFuelImports[c in consumers_ports,s in  suppliers_ports, f in traded_fuels,l in locations,ll in locations,mode in modes, y in years; 
                        haskey(iLm, (l,c)) && haskey(iLm, (ll,s))  && adj[l][ll][mode]>0 && EndoFuels[f]==1 && sFm[s,f]==1]>=0)
                        
### Fuel Selling Constraing
@constraint(m, FuellSellingConstrained1[s in  suppliers,f in traded_fuels,l in locations,y in years;(EndoFuels[f]==1 && haskey(iLm,(l,s))) && sFm[s,f]==1],
                    sum(qFuelSold[s,c,f,l,ll,y] for c in consumers, ll in locations if haskey(iLm, (ll,c)) && FuelUse[f,c]==1) 
                    <= sum(qProcess[s,ρ,l,y] for ρ in processes if haskey(sO,(s,ρ,f,y)))
                    )

### Import constraint: Consumers cannot import more than they have bought/ than was sold to them
@constraint(m, FuelImportConstraint2[c in  consumers,f in traded_fuels,l in locations,y in years;EndoFuels[f]==1 && haskey(iLm, (l,c)) && FuelUse[f,c]==1],
                    qFuelPurchased[c,f,l,y]
                    ==  sum(qFuelImports[c,s,f,l,ll,m,y] for s in suppliers_port, ll in locations,m in modes 
                    if haskey(iLm, (l,c)) && haskey(iLm, (ll,s))  && adj[l][ll][m]>0 && EndoFuels[f]==1 && FuelUse[f,c]==1  && sFm[s,f]==1)
                    )
                    
# Introduction of losses
transportLosses =  readcsv("_transportLosses.csv",dir=data_dir)
transportLosses[!,"Losses"] = replace.(transportLosses[:,"Losses"],"," =>".")
transportLosses[!,"Losses"] = parse.(Float64,transportLosses[:,"Losses"])
transportLosses = Dict((transportLosses[i,:Commodity],transportLosses[i, :Mode]) => transportLosses[i, :Losses] for i in 1:nrow(transportLosses))

transportFuelConsumption =  readcsv("_tranposrt_fuel_consumption.csv",dir=data_dir)
transportFuelConsumption[!,"Losses"] = replace.(transportFuelConsumption[:,"Losses"],"," =>".")
transportFuelConsumption[!,"Losses"] = parse.(Float64,transportFuelConsumption[:,"Losses"])
transportFuelConsumption = Dict((transportFuelConsumption[i,:Commodity],transportFuelConsumption[i, :Mode]) => transportFuelConsumption[i, :Losses] for i in 1:nrow(transportFuelConsumption))



@constraint(m, ImportExportBalance[s in suppliers_ports, c in consumers_ports, f in traded_fuels, l in locations, ll in locations, mode in modes, y in years;
                haskey(iLm, (l, s)) && haskey(iLm, (ll, c)) && l != ll && (adj[l][ll][mode] > 0) && sFm[s,f] == 1],
    sum(qFuelPurchased[cc, f, l, y] for cc in consumers if haskey(iLm,(l,cc)))
    + qFuelExports[s, c, f, l, ll, mode, y] * (1 - transportLosses[f, mode] / 100 * adj[l][ll][mode]) 
    # - transportFuelConsumption[f, mode] * adj[l][ll][mode] 
    == qFuelImports[c, s, f, ll, l, mode, y]
    + sum(qFuelSold[s, cc, f, l, ll,y] for ss in suppliers, cc in consumers if haskey(iLm,(l,ss)) && haskey(iLm,(ll,cc)) )  
)



########### Hydrogen Market Constraint
@constraint(m, FuelMarketConstraintCheck4[f in traded_fuels,l in locations,y in years; EndoFuels[f]==1],
            sum(qFuelImports[c,s,f,l,ll,m,y] for c in consumers_ports,s in  suppliers_ports, ll in locations,m in modes if ll!=l && haskey(iLm, (l,c)) && haskey(iLm, (ll,s))  && adj[ll][l][m]>0 && sFm[s,f]==1)
        +   sum(qFuelSold[s,c,f,l,ll,y] for s in  suppliers, c in consumers, ll in locations if haskey(iLm, (l,s)) && ll!=l && haskey(iLm,(ll,c)) && sFm[s,f]==1) 
        == 
            sum(qFuelPurchased[c,f,l,y] for c in consumers if FuelUse[f,c]==1 && haskey(iLm, (l,c))) 
        +   sum(qFuelExports[s,c,f,l,ll,m,y]
            for s in  suppliers_ports, c in consumers_ports, ll in locations, m in modes if ll!=l && haskey(iLm, (l,s)) && haskey(iLm, (ll,c)) && adj[l][ll][m]>0 && sFm[s,f]==1)  
)   



########### Carbon Market Constraint λCO2
# Emission Allowances
eA =  readcsv("_e_benchmark.csv",dir=data_dir)
eA[!,"Value"] = replace.(eA[:,"Value"],"," =>".")
eA[!,"Value"] = parse.(Float64,eA[:,"Value"])
eA = Dict((eA[i,:Process], eA[i,:Year]) => eA[i, :Value] for i in 1:nrow(eA))

@constraint(m, EmissionMarketConstraint3[y in years],
            sum(qCO2[c,l,y] for c in consumers, l in locations if haskey(iLm,(l,c))) <= 
            sum(eA[c,y] * Q[c,g,l,y] for g in goods, c in consumers, l in locations if haskey(iLm,(l,c)) && haskey(eA, (c,y)))
)



@objective(m,Min,
    # sum(C[f]  * qFuelSold[p,f,l,y] / (1+DiscountRate)^(y - minimum(y)) for s in  suppliers, f in fuels,l in locations, y in years if (EndoFuels[f]==1 && haskey(C,f)) && haskey(iLm, (l,p)))
    + sum(qFuelPurchased[i,f,l,y] * P[f,y] / (1+DiscountRate)^(y - minimum(y)) for i in industries, f in purchased_fuel, l in locations, y in years if  (EndoFuels[f]==0 && FuelUse[f,i]==1 && haskey(iLm, (l,i))))
    + sum(NewCapacity[i, ρ,l,y] * K[ρ,y] / (1+DiscountRate)^(y - minimum(y)) for i in industries, ρ in processes, l in locations, y in years if  pIm[i,ρ]==1 && haskey(iLm, (l,i)))
    + 10* sum(qFuelExports[s,c,f,l,ll,m,y] for s in suppliers_ports, c in consumers_ports,f in traded_fuels, l in locations, ll in locations, m in modes, y in years if ll!=l && haskey(iLm, (l,s)) && haskey(iLm, (ll,c)) && adj[l][ll][m]>0 && EndoFuels[f]==1 && sFm[s,f]==1)
    # sum(SalvageValue[i,ρ,l,y] for i in industries, ρ in processes, l in locations, y in years if  (pIm[i,ρ]==1))
    )

optimize!(m)   

m

value.(qFuelPurchased)

value.(qFuelSold)

value.(NewCapacity)
value.(qProcessFuelDemand)
value.(qProcess)

########### Plot Fuel Demand
qFuelPurchased = DataFrame(Containers.rowtable(value,qFuelPurchased; header = [:industry,:fuel,:region, :year, :value])
)
qFuelPurchased = combine(groupby(qFuelPurchased, [:fuel,:year]), :value => sum)
df = qFuelPurchased

# Colors
fuel_colors = Dict(
    "H2" => "#96ffff",         # Hydrogen (Light Cyan)
    "NH3" => "#90EE90",        # Ammonia (Light Green)
    "Gas" => "#8B4513",        # Gas (SaddleBrown)
    "Coal" => "#696969",       # Coal (DimGray)
    "Electricity" => "#FFD700",# Electricity (Gold)
    "MGO" => "#e54213",        # Marine Gas Oil (Red)
    "Biodiesel" => "#228B22",  # Biodiesel (Forest Green)
    "LNG" => "#2F4F4F",        # Liquefied Natural Gas (Dark Slate Gray)
    "MeOH" => "#ADD8E6",       # Methanol (Light Blue)
    "Naphtha" => "#FF8C00",    # Naphtha (Dark Orange)
    "CO2" => "#808080",        # Carbon Dioxide (Gray)
    "CO" => "#A52A2A",         # Carbon Monoxide (Brown)
    "N" => "#00008B",          # Nitrogen (Dark Blue)
    "Biomass" => "#8FBC8F"     # Biomass (Dark Sea Green)
)

transform!(df, "fuel" => ByRow(x-> fuel_colors[x]) => "Color"
)
groupedbar(
    df.year,
    df.value_sum,
    group=df.fuel,
    bar_position=:stack,
    linewidth=0,
    color=df.Color, 
    title="Fuel Purchased" # Set the size of the plot to be 800x600 pixels
)

########### Plot  Process Fuels
df_qProcessFuelDemand= DataFrame(Containers.rowtable(value,qProcessFuelDemand; header = [:industry,:process,:fuel,:region, :year, :value])
)
df_qProcessFuelDemand = combine(groupby(df_qProcessFuelDemand, [:fuel,:year]), :value => sum)
df = df_qProcessFuelDemand

transform!(df, "fuel" => ByRow(x-> fuel_colors[x]) => "Color"
)
groupedbar(
    df.year,
    df.value_sum,
    group=df.fuel,
    bar_position=:stack,
    linewidth=0,
    color=df.Color, 
    title="Process Fuel Demand" # Set the size of the plot to be 800x600 pixels
)

##############################################################################################################
process_colors = Dict(
    # Steel Production
    "Bof" => "#B22222",        # Firebrick for Basic Oxygen Furnace (unchanged)
    "Dri" => "#FFD700",        # Gold for Direct Reduced Iron (unchanged)

    "Pv" => "#FFE993", # Solar PV 
    "Offwind" => "#5D6C88", #Offshore Wind
    "Onwind"  =>  "#adc1cf",

    # Hydrogen and Hydrogen-derived processes
    "El"=>"#30D5C8",
    "Smr" => "#FF8C00",        # Dark Orange for Steam Methane Reforming (distinct from Naphtha)
    "Hb" => "#4169E1",         # Royal Blue for Haber-Bosch Ammonia production (Hydrogen-related)
    "H2 ICE" => "#1E90FF",     # Dodger Blue for Hydrogen ICE (Hydrogen-related)
    "NH3 ICE" => "#4682B4",    # Steel Blue for Ammonia ICE (Hydrogen-related)
    "MeOH ICE" => "#87CEFA",   # Light Sky Blue for Methanol ICE (Hydrogen-related)
    "MeOHSyn1" => "#32CD32",   # LimeGreen for Methanol Synthesis (Hydrogen-related, unchanged)
    "MeOHSyn2" => "#98FB98",   # PaleGreen for Olefins and Aromatics from Synthetic Methanol (Hydrogen-related)

    # Naphtha and Gas-related processes
    "Nto/Nta" => "#A52A2A",        # Brown for Naphtha to Aromatics (Naphtha-related)
    "LNG ICE" => "#2F4F4F",    # Dark Slate Gray for LNG ICE (Gas-related)
    "Conventional ICE" => "#556B2F",  # Dark Olive Green for Conventional ICE (Fossil-related, unchanged)

    # Other processes
    "Mto/Mta" => "#9932CC",        # Dark Orchid for Methanol to Aromatics (unchanged)
    "Rwgs" => "#FF6347",       # Tomato for Reverse Water Gas Shift (unchanged)
    "Nitrification" => "#696969",  # Dark Gray for Nitrification (unchanged)
    "Asu" => "#87CEEB",        # Sky Blue for Air Separation of CO2 (unchanged)
    "Btm" => "#8FBC8F",        # Dark Sea Green for Biomass-to-Methanol (unchanged)
    "Dac" => "#008080"         # Teal for Direct Air Capture (unchanged)
)
df_Process= DataFrame(Containers.rowtable(value,qProcess; header = [:industry,:process,:region, :year, :value])
)

df_Process = combine(groupby(df_Process, [:process,:year]), :value => sum)
transform!(df_Process, "process" => ByRow(x-> process_colors[x]) => "Color"
)
groupedbar(
    df_Process.year,
    df_Process.value_sum,
    group=df_Process.process,
    bar_position=:stack,
    linewidth=0,
    color=df_Process.Color,
    title="Production by Process",   # Set the size of the plot to be 800x600 pixels
)


########### Plot  Sold Fuels

df_qFuelSold= DataFrame(Containers.rowtable(value,qFuelSold; header = [:producer,:consumer,:fuel,:Production_location,:Demand_location,:year, :value])
)
df_qFuelSold = combine(groupby(df_qFuelSold, [:producer,:Production_location,:year, :fuel]), :value => sum)
df_qFuelSold

filtered_df = filter(row -> row.value > 0, df_qFuelImports)
unique_combinations = unique(df_qFuelSold.Production_location)

colors_palette = distinguishable_colors(length(unique_combinations))
location_producer_colors = Dict(zip(unique_combinations, colors_palette))



# Create a new column 'fuel_location' by combining 'fuel' and 'Production_location'
transform!(df_qFuelSold, [:fuel, :Production_location] => ByRow(string) => :fuel_location)


# Generate unique combinations of 'fuel_location'
unique_combinations = unique(df_qFuelSold.fuel_location)

# Generate a palette of distinguishable colors
colors_palette = distinguishable_colors(length(unique_combinations))


# Create a dictionary mapping each fuel_location combination to a color
fuel_location_colors = Dict(zip(unique_combinations, colors_palette))

# Add a Color column based on the fuel_location combination
transform!(df_qFuelSold, :fuel_location => ByRow(x -> fuel_location_colors[x]) => :Color)

# Plot the data with different colors for each fuel and production location combination
groupedbar(
    df_qFuelSold.year,
    df_qFuelSold.value_sum,
    group=df_qFuelSold.fuel_location,
    bar_position=:stack,
    linewidth=0,
    color=df_qFuelSold.Color, 
    title="Fuels Sold by Location and type"
)

########### Exports and Imports
value.(qFuelExports)

########### Plot  Sold Fuels
df_qFuelExport = DataFrame(Containers.rowtable(value,qFuelExports; header = [:producer,:consumer,:fuel,:Production_location,:Demand_location,:mode,:year, :value])
)

filtered_df = filter(row -> row.value > 0, df_qFuelExport)


df_qFuelExport = DataFrame(Containers.rowtable(value,qFuelExports; header = [:producer,:consumer,:fuel,:Exporteur,:Importeur,:mode,:year, :value])
)
filtered_df = filter(row -> row.value > 0, df_qFuelExport)


df_qFuelPurchased = DataFrame(Containers.rowtable(value,qFuelPurchased; header = [:industry,:fuel,:region, :year, :value])
)
filtered_df = filter(row -> row.value > 0, df_qFuelPurchased)

df_qFuelImports = DataFrame(Containers.rowtable(value,qFuelImports; header = [:Importeur,:Exporteur,:fuel,:Demand_location,:Production_location,:mode,:year, :value])
)
filtered_df = filter(row -> row.value > 0, df_qFuelImports)


########### Plot Capacity Investments
df_Capacity = DataFrame(Containers.rowtable(value,NewCapacity; header = [:industry,:process,:locations, :year, :value]))
df_Capacity = combine(groupby(df_Capacity, [:process,:year]), :value => sum)
df_Capacity

transform!(df_Capacity, "process" => ByRow(x-> process_colors[x]) => "Color"
)

groupedbar(
    df_Capacity.year,
    df_Capacity.value_sum,
    group=df_Capacity.process,
    bar_position=:stack,
    title="",
    linewidth=0,
    color=df_Capacity.Color)  # Set the size of the plot to be 800x600 pixels
