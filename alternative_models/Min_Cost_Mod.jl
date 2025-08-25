# Setting up the Modeling Environment 
using Gurobi
using JuMP
using Revise


include("_DataImport.jl")
IOM, iNm,pIm,pFm, iNm, finalGoodProcessMap, rFm, FuelUse, P, sO, sI, sFm, K,ExportK, ResCap,Opex, R, D, sFuelSwitching, TechnologyLifetime,ExportLifeTime,sIm,eF,eA,pip_adj,shp_adj,sub_adj,transportLosses, transportFuelMap,pImports,importGoods,CO2Price, outputs,processes,fuels,cF,FOM,ExportFOM = import_data()


include("_MarketSetUp.jl")
market_data =  market_setup(    consumers=["Hvc", "Fertilizer", "Shipping", "Aviation", "Steel"],
                                nodes=["Hamburg","Chanaral","Teruel","Leverkusen", "Fiska", "Ludwigshafen", "Duisburg", "Antofagasta"],
                                years=[2030,2035,2040,2045,2050],
                                producers = ["Producer", "LC Producer"])

DiscountRate


consumers = market_data.consumers
producers = market_data.producers
producers_markets = market_data.producers_markets
ports = market_data.ports
producers_ports = market_data.producers_ports
consumers_ports = market_data.consumers_ports
nodes = market_data.nodes
                                
nodes_markets = market_data.nodes_markets
sectors = market_data.sectors
subsectors = market_data.subsectors
industries = market_data.industries
industries_ports = market_data.industries_ports

goods = market_data.goods

endo_fuels = market_data.endo_fuels
exo_fuels = market_data.exo_fuels

years = market_data.years
modes = market_data.modes
DiscountRate = market_data.DiscountRate
traded_fuels = market_data.traded_fuels
non_traded_fuels = market_data.non_traded_fuels
adj = market_data.adj
                                
# Assuming processes, fuels, outputs, years, and sI are defined
for ρ in processes, f in fuels
    if any(haskey(sI, (ρ, f, o, y)) for o in outputs, y in years)
        pFm[f, ρ] = 1  # Use pFm[f, ρ]! to set value
    end
end

# Correct EndoFuels:
for c in consumers,ρ in processes, f in fuels
        if any(haskey(sI, (ρ,f,o,y)) for o in outputs, y in years) && pIm[c,ρ]==1 &&   haskey(pFm, (f,ρ)) && pFm[f,ρ]==1
            if FuelUse[f,c]==0
                FuelUse[f,c]=1
            end 
        end
end


# Initialize Model
m = Model() 


# Demand Constraint 
################################### Variable
@variable(m,qProcess[i in industries_ports,ρ in processes, o in outputs, n in nodes, y in years; 
                    haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels if haskey(pFm, (f,ρ)))]>=0
)

@variable(m,qProcessFuelDemand[i in industries_ports, ρ in processes,f in fuels,o in outputs, n in nodes, y in years;
                    haskey(iNm,(n,i)) && pIm[i,ρ]==1 && haskey(sI,(ρ,f,o,y))]>=0)

@variable(m,qFuelPurchased[i in vcat(consumers, ["LC Producer"]),p in producers_markets, f in fuels,n in nodes,nn in nodes_markets,y in years; 
                    FuelUse[f,i]==1 && haskey(iNm, (n,i))  && haskey(iNm,(n,i)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f))]
                    >=0)


### Demand Constraint
@constraint(m, DemandConstraint[c in consumers,g in goods, n in nodes, y in years; haskey(D,(c,g,n,y)) && haskey(iNm,(n,c))],
            0 == sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
             - D[c,g,n,y] 
            )

### Fuel Balance Constraint 
@variable(m, qFuelExports[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
    haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1]>= 0
    )  
    
@variable(m,qFuelImports[c in consumers_ports,p in producers_ports, f in traded_fuels,n in nodes,nn in nodes,mode in modes, y in years; 
    haskey(iNm, (nn, p)) && haskey(iNm, (n, c)) && (adj[nn][n][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1]>= 0
)  


# EndoFuelBalance
@constraint(m, EndoFuelBalanceConstraint[i in industries_ports, f in traded_fuels, n in nodes, y in years; 
                FuelUse[f,i]==1 && haskey(iNm,(n,i))],
            sum(qFuelExports[i, c, f, n, nn, m, y]
            for  c in consumers_ports, nn in nodes, m in modes
            if haskey(qFuelExports, (i, c, f, n, nn, m, y)))  
            + sum(qProcessFuelDemand[i, ρ, f,o, n, y] for ρ in processes, o in outputs  if pIm[i,ρ]==1 && haskey(sI, (ρ,f,o,y)))
            <=
            sum(qFuelImports[i, p, f, n, nn, m, y]
            for p in producers_ports, nn in nodes, m in modes 
            if haskey(qFuelImports, (i, p, f, n, nn, m, y)))
            + sum(qProcess[i,ρρ,f,n, y] for ρρ in processes if haskey(qProcess, (i,ρρ,f,n, y)))
            )

# ExoFuelBalance
@constraint(m, ExoFuelBalanceConstraint[c in industries_ports, f in non_traded_fuels, n in nodes, y in years; FuelUse[f,c]==1 && haskey(iNm,(n,c))],
        0<= sum(qFuelPurchased[c,p, f, n,nn, y] for p in producers_markets, nn in nodes_markets if haskey(qFuelPurchased,(c,p, f, n,nn, y)))
            + sum(qProcess[c,ρρ,f,n, y] for ρρ in processes if haskey(qProcess,(c,ρρ,f,n, y)))
            - sum(qProcessFuelDemand[c, ρ, f,o, n, y] for ρ in processes, o in outputs if haskey(qProcessFuelDemand, (c, ρ, f,o, n, y)))
)

### Fuel Demand Constraint
@constraint(m, FuelDemandConstraint[i in industries_ports, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[i,ρ]==1 &&  sFuelSwitching[ρ,f]==0],
            qProcess[i,ρ,o,n,y] == 1/sI[ρ,f,o,y] *  qProcessFuelDemand[i,ρ,f,o,n,y])



### FuelSwichtingConstraintfue
@constraint(m, FuelSwichtingConstraintDual[i in industries_ports,ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,i)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[i,ρ]==1 for f in fuels)  && pIm[i,ρ]==1],
            qProcess[i,ρ,o,n,y] == sum( 1/ sI[ρ,f,o,y] *qProcessFuelDemand[i,ρ,f,o,n,y] for f in fuels
            if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[i,ρ]==1)
)


### RfnboConstraint constraint
@constraint(m, RfnboConstraint[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],              
                0<=
                sum((rFm[ρ,f,y] - R[s,y] ) * qProcessFuelDemand[cc, ρ, f,o, n, y] for cc in consumers, f in fuels,ρ in processes, o in outputs, n in nodes
               if haskey(qProcessFuelDemand, (cc, ρ, f,o, n, y)) && haskey(iNm,(n,cc)) && f∉["CO2", "CO", "N"] && haskey(sIm, (s,cc))))

#### Capacity Constraint
@variable(m, qAccCapacity[i in industries_ports,ρ in processes,n in nodes, y in years;haskey(pIm,(i,ρ)) && pIm[i,ρ]==1 && haskey(iNm,(n,i))]>=0)
@variable(m, qNewCapacity[i in industries_ports,ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1]>=0)

@constraint(m, CapacityConstraint1[i in industries,ρ in processes, n in nodes,y in years;haskey(pIm,(i,ρ))  && pIm[i,ρ]==1 && haskey(iNm,(n,i))],
                0<= qAccCapacity[i,ρ,n,y] - 1/cF[ρ,n] * sum(qProcess[i,ρ,o,n,y] for o in outputs if any(haskey(sI, (ρ,f, o, y)) for f in fuels)))

             
@constraint(m, CapacityAccountingFunction[i in industries_ports,ρ in processes, n in nodes,y in years;haskey(pIm,(i,ρ))  && pIm[i,ρ]==1 && haskey(iNm,(n,i))],
                0==sum(qNewCapacity[i,ρ,n,yy] for yy in years if yy<=y && yy - y <= TechnologyLifetime[ρ])  
                 + ResCap[i,ρ,n,y]
                - qAccCapacity[i,ρ,n,y]
        ) 


### Capacity Expansion Constraint for Producers
@constraint(m, CapacityExpansionConstraintFirstPeriod[p in producers, ρ in processes, n in nodes, y in years; y==years[1] && pIm[p,ρ]==1 && haskey(iNm,(n,p))],
                    qNewCapacity[p,ρ,n,y]  <= 0.4 * sum(qProcessFuelDemand[c,ρρ,f,o,nn,y] 
                    for c in consumers,ρρ in processes, f in fuels, o in outputs, nn in nodes if haskey(qProcessFuelDemand, (c,ρρ,f,o,nn,y)) && haskey(sO,(ρ,f)))
                    )

@constraint(m, CapacityExpansionConstraint[p in producers, ρ in processes, n in nodes, y in years; y>years[1] && pIm[p,ρ]==1 && haskey(iNm,(n,p))],
                    qNewCapacity[p,ρ,n,y]  <= 0.5 * qAccCapacity[p,ρ,n,y]
)

### Emission constraint
@variable(m, qCO2[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))]>=0)
@variable(m, qCO2ExMarket[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))]>=0)


@constraint(m, EmissionConstraint[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                0<= qCO2[c,n,y]
                - sum(eF[ρ,o] * qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if haskey(eF,(ρ,o)) && pIm[c,ρ]==1 && haskey(qProcess,(c,ρ,o,n,y)))
)

@constraint(m, EmissionMarketConstraint[c in consumers, n in nodes,y in years;haskey(iNm,(n,c))],
            0<=   qCO2ExMarket[c,n,y] - qCO2[c,n,y])


######################################################### Hydorgen Market
### Contract Clearing
@variable(m,qFuelSold[p in  producers,c in consumers,f in traded_fuels,n in nodes,nn in nodes,y in years;
                (haskey(iNm,(n,p))) &&  haskey(sFm, (p,f)) && sFm[p,f]==1 && haskey(iNm,(nn,c)) && FuelUse[f,c]==1]>=0)

@constraint(m, PhysicalFuelPurchasingConstraint2[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                qFuelPurchased[c,p,f,n,nn,y,] - qFuelSold[p,c,f,nn,n,y] ==0
                )


######################################################### Upper Level Constraints

### Export Capacity 
@variable(m, qExportAccCapacity[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
    haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1]>=0)

@variable(m, qExportNewCapacity[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
    haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1]>=0) 


### Export Capacity Counting
@constraint(m, ExportCapacityAccountingFunction2[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1],
                0<=sum(qExportNewCapacity[p, c, f, n, nn, mode, yy] for yy in years if yy<=y && yy - y <= ExportLifeTime[mode,f]) 
                - qExportAccCapacity[p, c, f, n, nn, mode, y]
                ) 

### Export Constraint Constraint
@constraint(m,ExportConstraints[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
    haskey(qExportAccCapacity, (p, c, f, n, nn, mode, y))],
    qFuelExports[p, c, f, n, nn, mode, y] <=  qExportAccCapacity[p, c, f, n, nn, mode, y]
    )   

### Import Export Balance
@constraint(m, ExportImportBalance[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            haskey(qFuelImports, (c, p, f, n, nn, mode, y)) && haskey(qFuelExports, (p, c , f, nn, n, mode, y))], 
                qFuelImports[c, p, f, n, nn, mode, y] <= (1 - adj[n][nn][mode] * transportLosses[f,mode]/100) * qFuelExports[p, c, f, nn, n, mode, y]
            )

######################################################### Market Clearing Constraint
            
######################################################### Objective function
# Exo Fuel Costs
@expression(m, ExoFuelCosts[y in years], 
            sum(qFuelPurchased[c, p,f, n,nn,y]*P[f,n,y] for c in consumers, p in producers_markets,f in exo_fuels, n in nodes, nn in nodes_markets 
            if FuelUse[f,c]==1 && haskey(sFm, (p,f)) && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(P, (f,n,y)))
)


# Capital Costs
@expression(m, CapitalCost[y in years], 
            sum(qNewCapacity[i,ρ,n,y]*K[ρ,y] for i in industries_ports, ρ in processes,n in nodes
            if haskey(iNm,(n,i)) && pIm[i,ρ]==1))

# Export Capital Cost
@expression(m, qExportCapacityCost[y in years],
                sum(qExportNewCapacity[p, c, f, n, nn, mode, y] * ExportK[mode,f,y] * adj[n][nn][mode]
                    for p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in ["pipeline"]
                    if haskey(qFuelExports, (p, c, f, n, nn, mode, y)))
                +  sum(qExportNewCapacity[p, c, f, n, nn, mode, y] * ExportK[mode,f,y]
                for p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in ["shipping"]
                if haskey(qFuelExports, (p, c, f, n, nn, mode, y))))

### FOM
@expression(m, FOMCost[y in years],
            sum(FOM[ρ,y] * qAccCapacity[i,ρ,n,y] for i in industries, ρ in processes, n in nodes if haskey(qAccCapacity,(i,ρ,n,y))))
            
@expression(m, ExportFOMCost[y in years], 
            sum(ExportFOM[mode,f,y] * adj[n][nn][mode] * qExportAccCapacity[p, c, f, n, nn, mode, y] for p in producers_ports,c in consumers_ports,f in traded_fuels, n in nodes,nn in nodes, mode in modes 
            if haskey(qExportAccCapacity,(p, c, f, n, nn, mode, y))))


# CO 2 Cost 
@expression(m, EmissionCost[y in years], sum(qCO2ExMarket[c,n,y]*CO2Price[y] for c in consumers, n in nodes if haskey(iNm,(n,c))))           


# Opex Cost
@expression(m, OpexCost[y in years],
            sum(Opex[ρ,y] * qProcess[i,ρ,o,n,y] for i in industries, ρ in processes,o in outputs, n in nodes if haskey(qProcess,(i,ρ,o,n,y))))

# Objective Function
@objective(m, Min, sum( 1/((1-DiscountRate)^(y - (years[1]))) * (ExoFuelCosts[y] + CapitalCost[y] + qExportCapacityCost[y] + EmissionCost[y]
                    + ExportFOMCost[y] + OpexCost[y]) for y in years))



# Link CO2 Markets
set_optimizer(m,Gurobi.Optimizer)
set_optimizer_attribute(m, "NumericFocus", 3) 
optimize!(m)


compute_conflict!(m)

# Export 
df_qFuelSold= DataFrame(Containers.rowtable(value, qFuelSold; header = [:Supplier,:Industry,:Fuel, :Origin,:Destination,:Year, :Value]))
filter(row -> row.Value != 0, df_qProcess)

df_qProcess= DataFrame(Containers.rowtable(value, qProcess; header = [:Industry,:Process,:Output, :Location, :Year, :Value]))
filter(row -> row.Value != 0, df_qProcess)

df_qProcessFuelDemand = DataFrame(Containers.rowtable(value, qProcessFuelDemand; header = [:Industry, :Process, :Input, :Output, :Location, :Year, :Value]))
filter(row -> row.Value != 0, df_qProcessFuelDemand)

df_qCO2ExMarket= DataFrame(Containers.rowtable(value, qCO2ExMarket; header = [:Industry,:Location,:Year,:Value]))
filter(row -> row.Value != 0, df_qCO2ExMarket)

df_qAccCapacity= DataFrame(Containers.rowtable(value, qAccCapacity; header = [:Industry,:Process, :Location, :Year, :Value]))
filter(row -> row.Value != 0, df_qAccCapacity)


df_qNewCapacity= DataFrame(Containers.rowtable(value, qNewCapacity; header = [:Industry,:Process, :Location, :Year, :Value]))
filter(row -> row.Value != 0, df_qNewCapacity)

df_qFuelImports= DataFrame(Containers.rowtable(value, qFuelImports; header = [:Industry,:Supplier,:Fuel, :Destination,:Origin,:Mode,:Year, :Value]))
filter(row -> row.Value != 0, df_qFuelImports)

df_qFuelExports= DataFrame(Containers.rowtable(value, qFuelExports; header = [:Supplier,:Industry,:Fuel, :Origin,:Destination,:Mode,:Year, :Value]))
filter(row -> row.Value != 0, df_qFuelExports)

df_qExportNewCapacity= DataFrame(Containers.rowtable(value, qExportNewCapacity; header = [:Supplier,:Industry,:Fuel,:Origin,:Destination,:Mode,:Year, :Value]))
filter(row -> row.Value != 0, df_qExportNewCapacity)

df_qExportAccCapacity= DataFrame(Containers.rowtable(value, qExportAccCapacity; header = [:Supplier,:Industry,:Fuel,:Origin,:Destination,:Mode,:Year, :Value]))
filter(row -> row.Value != 0, df_qExportNewCapacity)



results_filepath = mkpath("C:\\Users\\alex-\\Desktop\\09_11_Rechenkern\\_code\\results")
# write results to results directory in csv files
CSV.write(joinpath(results_filepath, "qFuelSold.csv"), df_qFuelSold)
CSV.write(joinpath(results_filepath, "qProcess.csv"), df_qProcess)
CSV.write(joinpath(results_filepath, "qProcessFuelDemand.csv"), df_qProcessFuelDemand)
CSV.write(joinpath(results_filepath, "qCO2ExMarket.csv"), df_qCO2ExMarket)

CSV.write(joinpath(results_filepath, "qAccCapacity.csv"), df_qAccCapacity)
CSV.write(joinpath(results_filepath, "qNewCapacity.csv"), df_qNewCapacity)

CSV.write(joinpath(results_filepath, "qFuelImports.csv"), df_qFuelImports)
CSV.write(joinpath(results_filepath, "qFuelExports.csv"), df_qFuelExports)
CSV.write(joinpath(results_filepath, "qNewExportsCapacity.csv"), df_qExportNewCapacity)
CSV.write(joinpath(results_filepath, "qExportsCapacity.csv"), qExportAccCapacity)