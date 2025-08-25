# Setting up the Modeling Environment 
include("_DataImport.jl")
include("_MarketSetUp.jl")


market_data = market_setup()
# Extract individual fields
consumers = market_data.consumers
producers = market_data.producers
ports = market_data.ports
producer_ports = market_data.producers_ports
consumers_ports = market_data.consumers_ports
locations = market_data.locations
sectors = market_data.sectors
subsector = market_data.subsectors
industries = market_data.industries
industries_ports = market_data.industries_ports
goods = market_data.goods
fuels = market_data.fuels
purchased_fuel = market_data.purchased_fuel
years = market_data.years
modes = market_data.modes
DiscountRate = market_data.DiscountRate
non_traded_fuels = market_data.non_traded_fuels
traded_fuels = market_data.traded_fuels
adj = market_data.adj
processes = market_data.processes

# Call the function to load data and create the objects
iLevelM,pFm, pIm, iLm, finalGoodProcessMap, rFm, FuelUse, EndoFuels, P, sO, sI, sFm, K, ResCap,Opex, R, D, sFuelSwitching,TechnologyLifetime, sIm,eF,eA,pip_adj,shp_adj,transportLosses,transportFuelMap  = import_data()


using Gurobi
using JuMP
######################################################### Initialize Model
m = Model(Gurobi.Optimizer)



@variable(m,qProcess[i in industries_ports,ρ in processes, l in locations, y in years; haskey(iLm,(l,i)) && pIm[i,ρ]==1]>=0
)

@variable(m,qProcessFuelDemand[i in industries_ports,ρ in processes,f in fuels, l in locations, y in years;haskey(iLm,(l,i)) && pIm[i,ρ]==1 && pFm[f,ρ]==1 && haskey(sI,(ρ,f,y))]>=0
)

@variable(m,qFuelPurchased[i in industries,p in producers_markets, f in fuels,l in locations,y in years; any(haskey(sI, (ρ,f,y)) for ρ in processes if pIm[i,ρ]==1)  && haskey(iLm,(l,i)) && sFm[p,f]==1]>=0
)

@variable(m,qFuelSold[p in  producers,c in consumers,f in traded_fuels,l in locations,ll in locations,y in years;
                (EndoFuels[f]==1 && haskey(iLm,(l,p))) && haskey(iLm,(ll,c)) && sFm[p,f]==1]>=0)

@variable(m, qFuelExports[p in producer_ports, c in consumers_ports, f in traded_fuels, l in locations, ll in locations, mode in modes, y in years;
    haskey(iLm, (l, p)) && haskey(iLm, (ll, c)) && (adj[l][ll][mode]>0)  && sFm[p,f]==1 && transportFuelMap[mode,f]==1]>= 0
    )  
    
@variable(m,qFuelImports[c in consumers_ports,p  in  producer_ports, f in traded_fuels,l in locations,ll in locations,mode in modes, y in years; 
                        haskey(iLm, (l,c)) && haskey(iLm, (ll,p))  && adj[l][ll][mode]>0 && sFm[p,f]==1 && transportFuelMap[mode,f]==1]>=0 
                        )
                            
# Downstream Constraints
######################################################### Downstream Demand Constraint 
@constraint(m, DemandConstraint[i in industries,g in goods, l in locations, y in years; haskey(D,(i,g,l,y)) && haskey(iLm,(l,i))],
            D[i,g,l,y] == sum(qProcess[i,ρ,l,y] for ρ in processes if pIm[i,ρ]==1 && haskey(finalGoodProcessMap, ρ) && finalGoodProcessMap[ρ]==g &&  haskey(iLm,(l,i)))
            )

######################################################### Fuel Inventory Constraint for Fuel Demand Self Production 
@constraint(m, FuelInventoryConstraint[i in industries, f in fuels, l in locations, y in years; any(haskey(sI, (ρ,f,y)) for ρ in processes if pIm[i,ρ]==1) && haskey(iLm,(l,i))],
    sum(qProcessFuelDemand[i, ρ, f, l, y] for ρ in processes if pIm[i,ρ]==1 && pFm[f,ρ]==1 && haskey(sI, (ρ,f,y))) == 
        sum(qFuelPurchased[i, f, l, y] for p in producers if sFm[p,f]==1)  + sum(sO[i, ρρ, f, y] * qProcess[i, ρρ, l, y]  for ρρ in processes if haskey(sO, (i, ρρ, f, y)) && pIm[i,ρ]==1)
)


######################################################### Zero Pruchase Constraint
@constraint(m, ZeroPurchaseConstraint[i in industries, f in non_traded_fuels, l in locations,y in years;  any(haskey(sI, (ρ,f,y)) for  ρ in processes, y in years)  && haskey(iLm,(l,i)) && FuelUse[f,i]==1],
                                    qFuelPurchased[i, f, l, y] == 0
                )

######################################################### Single Input Constraint
@constraint(m, InputConstraint[i in industries, ρ in processes,f in fuels,l in locations, y in years; haskey(iLm,(l,i)) && haskey(sI,(ρ,f,y)) && pFm[f,ρ]==1 && !haskey(sFuelSwitching,(i,ρ,f)) && pIm[i,ρ]==1],
    qProcess[i,ρ,l,y] * sI[ρ,f,y] <=  qProcessFuelDemand[i,ρ,f,l,y])

######################################################### Emission constraint
@variable(m,qCO2[c in consumers,l in locations,years; haskey(iLm, (l,c))]>=0)
@constraint(m, EmissionConstraint[c in consumers,l in locations, y in years; haskey(iLm,(l,c))],
                sum(eF[ρ] * qProcess[c,ρ,l,y] for ρ in processes if haskey(eF,ρ) && pIm[c,ρ]==1) <= qCO2[c,l,y])

  
######################################################### Duals: RFNBO Constraint for non Industry
@constraint(m, RfnboConstraint[s in sectors, y in years],
                R[s,y] * sum(qProcessFuelDemand[c, ρ, f, l, y] for c in consumers, ρ in processes, f in fuels,l in locations 
                if haskey(qProcessFuelDemand, (c,ρ,f,l,y)) && haskey(iLm,(l,c)) && f∉["Electricity", "CO2", "CO"] && haskey(sIm, (s,c)))
                <= sum(qProcessFuelDemand[c, ρ, f, l, y] for c in consumers, ρ in processes, f in fuels,l in locations 
                if haskey(qProcessFuelDemand, (c,ρ,f,l,y)) && haskey(iLm,(l,c)) && rFm[f] == 1 && haskey(sIm, (s,c))))
######################################################### Capacity
@variable(m, NewCapacity[i in industries,ρ in processes,l in locations, y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))]>=0)
@variable(m, AccumulatedCapacity[i in industries,ρ in processes,l in locations, y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))]>=0)
@constraint(m, CapacityAccountingFunction[i in industries,ρ in processes, l in locations,y in years;pIm[i,ρ]==1 && haskey(iLm,(l,i))],
    sum(NewCapacity[i,ρ,l,yy] for yy in years if yy<=y && y - yy <= TechnologyLifetime[ρ]) + ResCap[ρ,"GER",y] == AccumulatedCapacity[i,ρ,l,y]
)  

######################################################### Transport Capacity
@variable(m, TransportCapacity[p in producer_ports, i in industries_ports,f in traded_fuels,l in locations, ll in locations, mm in modes,y in years; 
                                        haskey(qFuelExports, (p,i,f,l,ll,mm,y))]>=0)

@constraint(m, ExportCapacityConstraint[p in producer_ports, i in industries_ports, f in traded_fuels, l in locations, ll in locations, mm in modes, y in years; 
                                        haskey(qFuelExports, (p,i,f,l,ll,mm,y))],
                                        qFuelExports[p,i,f,l,ll,mm,y] <= TransportCapacity[p,i,f,l,ll,mm,y]
                                        )
                                        
########### Hydrogen Market Constraint
@constraint(m, FuelMarketConstraint[f in traded_fuels,l in locations,y in years], 
            sum(qProcess[p,ρ,l,y] * sO[p,ρ,f,y] for p in ["Port"], ρ in processes if haskey(sO,(p,ρ,f,y)) && haskey(iLm,(l,p)))
        +   sum(qFuelImports[c,s,f,l,ll,m,y] for c in consumers_ports,s in  producer_ports, ll in locations,m in modes if haskey(qFuelImports, (c,s,f,l,ll,m,y)))     
        +   sum(qFuelSold[s,c,f,l,ll,y] for s in  producers, c in consumers, ll in locations if haskey(qFuelSold, (s,c,f,l,ll,y))) 
        == 
        +   sum(qFuelPurchased[c,p,f,l,y] for c in consumers, p in producers if haskey(qFuelPurchased, (c,p,f,l,y))) 
        +   sum(qFuelExports[p,c,f,l,ll,m,y]
            for p in  producer_ports, c in consumers_ports, ll in locations, m in modes if ll!=l && haskey(qFuelExports, (p,c,f,l,ll,m,y)))   
        + sum(qProcess[p,ρ,l,y]  *  sI[ρ,f,y] for p in ["Port"],ρ in processes if haskey(qProcess, (p,ρ,l,y)) && pFm[f,ρ]==1))


@objective(m,Min,
    + sum(qFuelPurchased[i,f,l,y] * P[f,y] / (1+DiscountRate)^(y - minimum(y)) for i in industries, f in purchased_fuel, l in locations, y in years if  (EndoFuels[f]==0 && FuelUse[f,i]==1 && haskey(iLm, (l,i))))
    + sum(NewCapacity[i, ρ,l,y] * K[ρ,y] / (1+DiscountRate)^(y - minimum(y)) for i in industries, ρ in processes, l in locations, y in years if  pIm[i,ρ]==1 && haskey(iLm, (l,i))))
    + sum(qProcessFuelDemand[])