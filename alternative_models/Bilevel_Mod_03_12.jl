# Setting up the Modeling Environment 
using Gurobi
using JuMP
using Revise


include("_DataImport.jl")
IOM, iNm,pIm,pFm, iNm, finalGoodProcessMap, rFm, FuelUse, P, sO, sI, sFm, K,ExportK, ResCap,Opex, R, D, sFuelSwitching, TechnologyLifetime,ExportLifeTime,sIm,eF,eA,pip_adj,shp_adj,sub_adj,transportLosses, transportFuelMap,pImports,importGoods,CO2Price, outputs,processes,fuels,cF,FOM,ExportFOM = import_data()

include("_MarketSetUp.jl")
market_data =  market_setup(    consumers=["Hvc", "Steel", "Fertilizer"],
                                nodes=["Hamburg","Chanaral","Teruel","Leverkusen", "Fiska", "Ludwigshafen", "Duisburg"],
                                years=[2040,2045,2050],
                                producers = ["Producer", "LC Producer"])

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
                                                      

# Check Dictionaries
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
#set_attribute(m, "TimeLimit", 210)
BIG = 1e12

data_dir = joinpath(@__DIR__, "data")

iLm = readcsv("_IndustryLevelMap.csv", dir=data_dir)
iLm = Dict((iLm[i, :Industry]) => iLm[i, :Level] for i in 1:nrow(iLm))


################################### Describing the lower Level ############################################
# Demand Constraint 
################################### Variable
@variable(m,qProcess[i in industries_ports,ρ in processes, o in outputs, n in nodes, y in years; 
                    haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels if haskey(pFm, (f,ρ)))]>=0
)

@variable(m,qProcessFuelDemand[i in industries_ports, ρ in processes,f in fuels,o in outputs, n in nodes, y in years;
                    haskey(iNm,(n,i)) && pIm[i,ρ]==1 && haskey(sI,(ρ,f,o,y)) && FuelUse[f,i]==1]>=0)

    
@variable(m, μFuelBalance[i in industries_ports, f in fuels,n in nodes,y in years; haskey(iNm, (n,i)) && FuelUse[f,i]==1]>=0)


################################### w.r.t. qProcessFuelDemand
@variable(m, μProcessesFuelDemand[i in industries,ρ in processes,f in fuels,o in outputs,n in nodes,y in years; 
                    haskey(iNm, (n,i)) && pIm[i,ρ]==1 && haskey(sI,(ρ,f,o,y)) && iLm[i]==0]
                    >=0)
                    
@variable(m, μFuelSwitchingProcessFuelDemand[i in industries,ρ in processes,o in outputs,n in nodes,y in years; 
                    haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels) && iLm[i]==0]>=0)

#@variable(m, μRFNBO[c in consumers,s in sectors,y in years; haskey(sIm, (s,c))]>=0)

@variable(m, rProcessFuelDemandFoc[i in industries,ρ in processes,f in fuels,o in outputs, n in nodes,y in years;
            pIm[i,ρ]==1  && haskey(iNm,(n,i)) && haskey(sI,(ρ,f,o,y))], Bin)


@constraint(m, ProcessFuelDemand[i in industries,ρ in processes, f in fuels,o in outputs,n in nodes,y in years;
                        pIm[i,ρ]==1  && haskey(iNm,(n,i)) && haskey(sI,(ρ,f,o,y)) && FuelUse[f,i]==1 && iLm[i]==0],
                         0<= μFuelBalance[i,f,n,y] 
 #                        - sum((R[s,y] - rFm[ρ,f,y])*μRFNBO[i,s,y] for s in sectors if  haskey(sIm, (s,i)) && f∉["CO2", "CO", "N"])  # RFNBO
                         - (1- sFuelSwitching[ρ,f]) * μProcessesFuelDemand[i,ρ,f,o,n,y]
                         - sFuelSwitching[ρ,f] * μFuelSwitchingProcessFuelDemand[i,ρ,o,n,y] 
                         )


@constraint(m, ProcessFuelDemand2[i in industries,ρ in processes, f in fuels,o in outputs,n in nodes,y in years;
                         pIm[i,ρ]==1  && haskey(iNm,(n,i)) && haskey(sI,(ρ,f,o,y)) && FuelUse[f,i]==1 && iLm[i]==0],
                          μFuelBalance[i,f,n,y] 
#                          - sum((R[s,y] - rFm[ρ,f,y])*μRFNBO[i,s,y] for s in sectors if  haskey(sIm, (s,i)) && f∉["CO2", "CO", "N"])  # RFNBO
                          - (1- sFuelSwitching[ρ,f]) * μProcessesFuelDemand[i,ρ,f,o,n,y]
                          - sFuelSwitching[ρ,f] * μFuelSwitchingProcessFuelDemand[i,ρ,o,n,y] 
                          <= rProcessFuelDemandFoc[i,ρ,f,o,n,y] *BIG
                          )

          
@constraint(m, ProcessFuelDemand3[i in industries,ρ in processes,f in fuels,o in outputs,n in nodes,y in years;
                        pIm[i,ρ]==1  && haskey(iNm,(n,i)) && haskey(sI,(ρ,f,o,y)) && FuelUse[f,i]==1 && iLm[i]==0],
                         qProcessFuelDemand[i,ρ,f,o,n,y] <= (1-rProcessFuelDemandFoc[i,ρ,f,o,n,y])*BIG)
     
################################### w.r.t. qProcesses
@variable(m, λFGMC[c in consumers, g in goods, n in nodes, y  in years; 
                        haskey(D,(c,g,n,y)) && haskey(iNm,(n,c))])

@variable(m, rProcessFOC[i in industries,ρ in processes,o in outputs, n in nodes, y in years; 
                        haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels) && iLm[i]==0], Bin)

@variable(m, μCO2[c in consumers,n in nodes,years; 
                        haskey(iNm, (n,c)) && iLm[c]==0]>=0)#

@variable(m, μCapacityConstraint[i in industries_ports, ρ in processes, n in nodes, y in years; haskey(iNm,(n,i)) && pIm[i,ρ]==1  && iLm[i]==0]>=0)

@constraint(m, ProcessFoc[i in industries, ρ in processes,o in outputs,n in nodes, y in years; 
                        haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels) && iLm[i]==0],
                0<=
                Opex[ρ,y] + μCapacityConstraint[i,ρ,n,y]
                + sum( (1- sFuelSwitching[ρ,f])  * μProcessesFuelDemand[i,ρ,f,o,n,y] * sI[ρ,f,o,y] 
                + sFuelSwitching[ρ,f]   *   μFuelSwitchingProcessFuelDemand[i,ρ,o,n,y] * sI[ρ,f,o,y] for f in fuels if haskey(sI, (ρ,f,o,y)))
                +  (haskey(μCO2, (i,n,y))  ?   eF[ρ,o] *  μCO2[i,n,y] : 0)
                - (haskey(μFuelBalance, (i, o,n, y)) ? μFuelBalance[i, o,n, y] : 0)  # Check for existence, else use 0
                - (any(haskey(λFGMC, (i,g,n,y))  for g in goods if g==o) ? sum(λFGMC[i,g,n,y] for g in goods if g==o) : 0) 
                )
  

@constraint(m, ProcessFoc2[i in industries, ρ in processes,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels) && iLm[i]==0],
                Opex[ρ,y] + μCapacityConstraint[i,ρ,n,y]
                + sum( (1- sFuelSwitching[ρ,f])  * μProcessesFuelDemand[i,ρ,f,o,n,y] * sI[ρ,f,o,y] 
                + sFuelSwitching[ρ,f]   *   μFuelSwitchingProcessFuelDemand[i,ρ,o,n,y] * sI[ρ,f,o,y] for f in fuels if haskey(sI, (ρ,f,o,y)))
                +  (haskey(μCO2, (i,n,y))  ?   eF[ρ,o] *  μCO2[i,n,y] : 0)
                - (haskey(μFuelBalance, (i, o,n, y)) ? μFuelBalance[i, o,n, y] : 0)  # Check for existence, else use 0
                - (any(haskey(λFGMC, (i,g,n,y))  for g in goods if g==o) ? sum(λFGMC[i,g,n,y] for g in goods if g==o) : 0) 
                <= rProcessFOC[i,ρ,o,n,y] * BIG
            )

@constraint(m, ProcessFoc3[i in industries, ρ in processes,o in outputs,n in nodes, y in years; 
            haskey(iNm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels) && iLm[i]==0],
            qProcess[i,ρ,o,n,y] <= (1 - rProcessFOC[i,ρ,o,n,y]) * BIG
            )


################################### w.r.t. Acc Capacity : qAccCapacity[c,ρ,n,y]
@variable(m, qProcessCapacity[i in industries_ports,ρ in processes,n in nodes, y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i))  && iLm[i]==0]>=0)

@variable(m, μCapacityAccumulation[i in industries_ports, ρ in processes, n in nodes, y in years; haskey(iNm,(n,i)) && pIm[i,ρ]==1  && iLm[i]==0]>=0)
@variable(m, rCapacityAccFoc[i in industries_ports, ρ in processes, n in nodes, y in years; haskey(iNm,(n,i)) && pIm[i,ρ]==1  && iLm[i]==0],Bin)

@constraint(m,  CapacityAccFoc[i in industries, ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1 && iLm[i]==0],
                0<= FOM[ρ,y] +  μCapacityAccumulation[i,ρ,n,y] - μCapacityConstraint[i,ρ,n,y]
            )

@constraint(m,  CapacityAccFoc2[i in industries,ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1 && iLm[i]==0],
                FOM[ρ,y] +  μCapacityAccumulation[i,ρ,n,y] - μCapacityConstraint[i,ρ,n,y] <= rCapacityAccFoc[i,ρ,n,y]*BIG
        )

@constraint(m,  CapacityAccFoc3[i in industries,ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1 && iLm[i]==0],
                qProcessCapacity[i,ρ,n,y] <= (1-rCapacityAccFoc[i,ρ,n,y])*BIG
)


################################### w.r.t. New Capacity
@variable(m, rNewCapacityFoc[i in industries,ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1 && iLm[i]==0], Bin)
@variable(m, qNewCapacity[i in industries, ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1 && iLm[i]==0 ]>=0)


@constraint(m, NewCapacityFoc[i in industries, ρ in processes, n in nodes, y in years; haskey(iNm,(n,i)) && pIm[i,ρ] == 1 && iLm[i]==0],
                        0 <=  K[ρ,y] - sum(μCapacityAccumulation[i,ρ,n,yy] for yy in years if yy>=y && yy - y <= TechnologyLifetime[ρ])
)


@constraint(m,  NewCapacityFoc2[i in industries, ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1 && iLm[i]==0],
                        K[ρ,y] - sum(μCapacityAccumulation[i,ρ,n,yy] for yy in years if yy>=y && yy - y <= TechnologyLifetime[ρ]) <= rNewCapacityFoc[i,ρ,n,y]*BIG
        )

@constraint(m,  NewCapacityFoc3[i in industries, ρ in processes, n in nodes, y in years;haskey(iNm,(n,i)) && pIm[i,ρ]==1  && iLm[i]==0],
                qNewCapacity[i,ρ,n,y] <= (1-rNewCapacityFoc[i,ρ,n,y])*BIG
)



################################### Carbon Purchased
@variable(m, qCO2ExMarket[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))]>=0)
@variable(m, rCO2ExMarket1[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))],Bin)

@constraint(m, CO2ExMarket[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))], 
                0 <= CO2Price[y] - μCO2[c,n,y]
                )

@constraint(m, CO2ExMarket2[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))], 
                CO2Price[y] - μCO2[c,n,y] <= rCO2ExMarket1[c,n,y]*BIG
                )

@constraint(m, CO2ExMarket3[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))], 
                qCO2ExMarket[c,n,y] <= (1-rCO2ExMarket1[c,n,y])*BIG
                )

###################################################################################################################################################################
######################################################### Fuel Export FOC
### Export FOC#
@variable(m, qFuelExports[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))]>=0
            )

@variable(m, μExportConstraint[p in producers_ports, f in traded_fuels,n in nodes, y in years; iLm[p]==0 && haskey(sFm,(p,f))]>=0)

@variable(m, μExportCapacity[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 && FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))]>=0
            )

          
@variable(m, μExportImportBalance[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
                FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))]>=0
            )

@variable(m,rExportFoc[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 &&FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],Bin)


@constraint(m,ExportFoc1[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 && FuelUse[f,p]==1  && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
            0<= μFuelBalance[p,f,n, y] 
                + μExportCapacity[p,c,f,n,nn,mode,y]
                - μExportConstraint[p,f,n,y]
               -(1 - adj[n][nn][mode] * transportLosses[f,mode]/100) * μExportImportBalance[p, c, f, n, nn, mode, y] 
            )

@constraint(m,ExportFoc2[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
                iLm[p]==0 &&FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
                μFuelBalance[p,f,n, y] 
                + μExportCapacity[p,c,f,n,nn,mode,y]
                - μExportConstraint[p,f,n,y]
                -(1 - adj[n][nn][mode] * transportLosses[f,mode]/100) * μExportImportBalance[p, c, f, n, nn, mode, y] 
                <= rExportFoc[p,c,f,n,nn,mode,y] * BIG
            )

@constraint(m,ExportFoc3[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 &&FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
            qFuelExports[p,c,f,n,nn,mode,y] <= (1-rExportFoc[p,c,f,n,nn,mode,y]) * BIG)


######################################################### Import - FOC
### Import Export Balance
@variable(m,qFuelImports[c in consumers_ports,p in producers_ports,f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[nn][n][mode]>0 && haskey(iNm,(nn,p)) && haskey(iNm, (n,c))]>=0)


@variable(m, μImportConstraint[c in consumers_ports,f in traded_fuels,n in nodes, y in years;
            FuelUse[f,c]==1 && haskey(iNm,(n,c))])

@variable(m,rImportFoc[c in consumers_ports,p in producers_ports,f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[nn][n][mode]>0 && haskey(iNm,(nn,p)) && haskey(iNm, (n,c))],Bin)

@constraint(m,ImportFoc[c in consumers_ports,p in producers_ports,f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[nn][n][mode]>0 && haskey(iNm,(nn,p)) && haskey(iNm, (n,c))],
            0<= μImportConstraint[c,f,n,y]  
                + μExportImportBalance[p,c,f,nn,n,mode,y]
                - μFuelBalance[c,f,n,y]
            )

@constraint(m,ImportFoc21[c in consumers_ports,p in producers_ports,f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[nn][n][mode]>0 && haskey(iNm,(nn,p)) && haskey(iNm, (n,c))],
            μImportConstraint[c,f,n,y]  
                + μExportImportBalance[p,c,f,nn,n,mode,y]
                - μFuelBalance[c,f,n,y]
            <= rImportFoc[c,p,f,n,nn,mode,y] * BIG
            )

@constraint(m,ImportFoc31[c in consumers_ports,p in producers_ports,f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            iLm[c]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[nn][n][mode]>0 && haskey(iNm,(nn,p)) && haskey(iNm, (n,c))],
            qFuelImports[c,p,f,n,nn,mode,y] <= (1- rImportFoc[c,p,f,n,nn,mode,y]) *BIG
)


################################### w.r.t.Export Acc Capacity
@variable(m, qExportAccCapacity[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))]>=0)

@variable(m, qExportNewCapacity[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))]>=0) 


# Duals
@variable(m, μExportCapacityAccFunction[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))]>=0)

@variable(m, rExportCapacityAccFoc[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],Bin)

### Export Capacity Foc 
@constraint(m,  ExportCapacityAccFoc[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
                0<= μExportCapacityAccFunction[p, c, f, n, nn, mode, y]  - μExportCapacity[p, c, f, n, nn, mode, y]
            )

@constraint(m,  ExportCapacityAccFoc2[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
                μExportCapacityAccFunction[p, c, f, n, nn, mode, y]  - μExportCapacity[p, c, f, n, nn, mode, y] <= rExportCapacityAccFoc[p, c, f, n, nn, mode, y]*BIG
)

@constraint(m,  ExportCapacityAccFoc3[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
            qExportAccCapacity[p, c, f, n, nn, mode, y] <= (1-rExportCapacityAccFoc[p, c, f, n, nn, mode, y])*BIG
)


################################### w.r.t. New Export Capacity
@variable(m, rExportNewCapacityFoc[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                    iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))], Bin)

@constraint(m, NewExportCapacityFoc[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                    iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
                        0 <=  ExportK[mode,f,y] * adj[n][nn][mode] - sum(μExportCapacity[p, c, f, n, nn, mode, y] for yy in years if yy>=y && yy - y <= ExportLifeTime[mode,f])
)


@constraint(m,  NewExportCapacityFoc2[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
                ExportK[mode,f,y] * adj[n][nn][mode] - sum(μExportCapacity[p, c, f, n, nn, mode, y] for yy in years if yy>=y && yy - y <= ExportLifeTime[mode,f]) 
                <= rExportNewCapacityFoc[p, c, f, n, nn, mode, y]*BIG
        )

@constraint(m,  NewExportCapacityFoc3[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
            iLm[p]==0 && FuelUse[f,p]==1 && FuelUse[f,c]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c))],
            qExportNewCapacity[p, c, f, n, nn, mode, y] <= (1-rExportNewCapacityFoc[p, c, f, n, nn, mode, y])*BIG
)

######################################################### ######################################################################################### 
######################################################### FuelSold and Fuel Purchased FOC #########################################################
@variable(m,qFuelPurchased[i in vcat(consumers, ["LC Producer"]),p in producers_markets, f in fuels,n in nodes,nn in nodes_markets,y in years; 
                    FuelUse[f,i]==1 && haskey(iNm, (n,i))  && haskey(iNm,(n,i)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f))]
                    >=0)   

@variable(m, rqFuelPurchasedFoc[i in industries_ports,p in producers_markets, f in fuels,n in nodes, nn in nodes_markets,y in years;
            FuelUse[f,i]==1  && haskey(iNm,(n,i)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f)) && iLm[i]==0])

@variable(m, λ[c in consumers,p in producers,f in traded_fuels, n in nodes,nn in nodes,y in years; 
            FuelUse[f,c]==1  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f)) && iLm[c]==0]>=0
            )


################################### w.r.t. Endo qFuelPurchased          
@constraint(m, FuelPurchasedFOC1[c in consumers,p in producers,f in traded_fuels,n in nodes,nn in nodes,y in years; 
                        FuelUse[f,c]==1  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f)) && iLm[c]==0],
                        0<=   λ[c,p,f,n,nn,y] - μImportConstraint[c,f,n,y])


@constraint(m, FuelPurchasedFOC2[c in consumers,p in producers,f in traded_fuels,n in nodes,nn in nodes,y in years; 
                        FuelUse[f,c]==1 && haskey(iNm, (n,c))  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f)) && iLm[c]==0],
                        λ[c,p,f,n,nn,y] - μImportConstraint[c,f,n,y]   <= rqFuelPurchasedFoc[c,p,f,n,nn,y]*BIG)


@constraint(m, FuelPurchasedFOC3[c in consumers,p in producers,f in traded_fuels,n in nodes,nn in nodes,y in years;
                        FuelUse[f,c]==1 && haskey(iNm, (n,c))  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f)) && iLm[c]==0],
                        qFuelPurchased[c,p,f,n,nn,y] <= (1-rqFuelPurchasedFoc[c,p,f,n,nn,y])*BIG)


################################### w.r.t. qFuelSold  
@variable(m, qFuelSold[p in producers, c in consumers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                        FuelUse[f,c]==1 && haskey(sFm,(p,f)) && haskey(iNm,(n,p)) &&  haskey(iNm,(nn,c))]
            )

@variable(m, rqFuelSolddFoc[p in producers, c in consumers, f in traded_fuels,n in nodes, nn in nodes, y in years;
            FuelUse[f,c]==1  && haskey(iNm,(n,p)) && haskey(iNm,(nn,c)) && haskey(sFm, (p,f)) && iLm[p]==0])

@variable(m, μFuelSold[p in producers, c in consumers, f in traded_fuels,n in nodes, nn in nodes,y in years;
                        FuelUse[f,c]==1 && haskey(sFm,(p,f)) && haskey(iNm,(n,c)) && haskey(iNm,(nn,p))]
            )

### FOC Fuel Sold
@constraint(m, FuelSoldFOC1[p in producers, c in consumers, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            haskey(sFm,(p,f)) && haskey(iNm,(n,p)) && iLm[p]==0 && haskey(iNm,(nn,c)) && FuelUse[f,c]==1],
            0<=   μExportConstraint[p,f,n,y] - λ[c,p,f,nn,n,y]
            )


@constraint(m, FuelSoldFOC2[p in producers,f in traded_fuels,n in nodes,y in years,c in consumers, nn in nodes; 
            haskey(sFm,(p,f)) && haskey(iNm,(n,p)) && iLm[p]==0 && FuelUse[f,c]==1 && haskey(iNm,(nn,c))],
            μExportConstraint[p,f,n,y] - λ[c,p,f,nn,n,y] <= rqFuelSolddFoc[p,c,f,n,nn,y]*BIG)


@constraint(m, FuelSoldFOC3[c in consumers,p in producers,f in traded_fuels,n in nodes,nn in nodes, y in years; 
            FuelUse[f,c]==1 && haskey(iNm, (n,p))  && haskey(iNm,(nn,c)) && haskey(sFm, (p,f)) && iLm[p]==0 && FuelUse[f,c]==1],
            qFuelSold[p,c,f,n,nn,y] <=   (1-rqFuelSolddFoc[p,c,f,n,nn,y])*BIG
            )


################################## w.r.t. qFuelPurchased -- Exogenous Fuels
@constraint(m, FuelPurchasedFocNonTraded[i in industries,f in exo_fuels, n in nodes,y in years;
                        FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0 && haskey(sFm, ("Market", f))],
                        0<=   P[f,n,y]  -  μFuelBalance[i,f,n,y] )

@constraint(m, FuelPurchasedFocNonTraded21[i in industries,f in exo_fuels ,n in nodes,y in years;
                    FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0 && haskey(sFm, ("Market", f))],
                        P[f,n,y]  - μFuelBalance[i,f,n,y] <= rqFuelPurchasedFoc[i,"Market",f,n,"Local",y]*BIG
                        )

@constraint(m, FuelPurchasedFocNonTraded4[i in industries,f in exo_fuels ,n in nodes,y in years;
                    FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0 && haskey(sFm, ("Market", f))],
                        qFuelPurchased[i,"Market",f,n,"Local",y] <= (1-rqFuelPurchasedFoc[i,"Market",f,n,"Local",y])*BIG)


#################################################################################################################################################################################
######################################################## Lower Level Duals ######################################################################################################
#################################################################################################################################################################################
#### Demand Constraint : defining λFGMC[c,g,n,y]

@variable(m, rDemandConstraint[c in consumers, g in goods, n in nodes, y in years;haskey(D,(c,g,n,y)) && haskey(iNm,(n,c))],Bin)

@constraint(m, DemandConstraint[c in consumers,g in goods, n in nodes, y in years; haskey(D,(c,g,n,y)) && haskey(iNm,(n,c))],
            0 <= sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
             - D[c,g,n,y] 
            )

@constraint(m, DemandConstraint21[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
            sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
             - D[c,g,n,y] 
            <= rDemandConstraint[c,g,n,y] * BIG
            )

@constraint(m, DemandConstraint31[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
                λFGMC[c,g,n,y]  <= (1 - rDemandConstraint[c,g,n,y]) * BIG
            )
   


######################################################### Fuel Endo Balance Constraint : μFuelBalance
### EndoFuelBalance
@variable(m, rFuelBalanceConstraint[i in industries, f in fuels, n in nodes, y in years;  FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0], Bin)


@constraint(m, EndoFuelBalanceConstraint1[i in industries_ports, f in traded_fuels, n in nodes, y in years; 
            FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
            0<= sum(qFuelImports[i, p, f, n, nn, mode, y]
            for p in producers_ports, nn in nodes, mode in modes 
            if haskey(qFuelImports, (i, p, f, n, nn, mode, y)))
            + sum(qProcess[i,ρρ,f,n, y] for ρρ in processes if haskey(qProcess, (i,ρρ,f,n, y)))
            -(
             sum(qFuelExports[i, c, f, n, nn, mode, y]
            for  c in consumers_ports, nn in nodes, mode in modes
            if haskey(qFuelExports, (i, c, f, n, nn, mode, y)))  
            +sum(qProcessFuelDemand[i, ρ, f,o, n, y] for ρ in processes, o in outputs  if pIm[i,ρ]==1 && haskey(sI, (ρ,f,o,y)))
            )
            )

@constraint(m, EndoFuelBalanceConstraint2[i in industries, f in traded_fuels, n in nodes, y in years; 
            FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
            sum(qFuelImports[i, p, f, n, nn, mode, y]
            for p in producers_ports, nn in nodes, mode in modes 
            if haskey(qFuelImports, (i, p, f, n, nn, mode, y)))
            + sum(qProcess[i,ρρ,f,n, y] for ρρ in processes if haskey(qProcess, (i,ρρ,f,n, y)))
            -(
             sum(qFuelExports[i, c, f, n, nn, mode, y]
            for  c in consumers_ports, nn in nodes, mode in modes
            if haskey(qFuelExports, (i, c, f, n, nn, mode, y)))  
            +sum(qProcessFuelDemand[i, ρ, f,o, n, y] for ρ in processes, o in outputs  if pIm[i,ρ]==1 && haskey(sI, (ρ,f,o,y)))
            )
            <= rFuelBalanceConstraint[i,f,n,y] * BIG
            )
######################################################### Fuel Exo Balance Constraint : μFuelBalance
### Exo FuelBalance
@constraint(m, ExoFuelBalanceConstraint1[i in industries, f in non_traded_fuels, n in nodes, y in years; FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
        0<= sum(qFuelPurchased[i,p, f, n,nn, y] for p in producers_markets, nn in nodes_markets if haskey(qFuelPurchased,(i,p, f, n,nn, y)))
            + sum(qProcess[i,ρρ,f,n, y] for ρρ in processes if haskey(qProcess,(i,ρρ,f,n, y)))
            - sum(qProcessFuelDemand[i, ρ, f,o, n, y] for ρ in processes, o in outputs if haskey(qProcessFuelDemand, (i, ρ, f,o, n, y)))
)

@constraint(m, ExoFuelBalanceConstraint2[i in industries, f in non_traded_fuels, n in nodes, y in years; FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
            sum(qFuelPurchased[i,p, f, n,nn, y] for p in producers_markets, nn in nodes_markets if haskey(qFuelPurchased,(i,p, f, n,nn, y)))
            + sum(qProcess[i,ρρ,f,n, y] for ρρ in processes if haskey(qProcess,(i,ρρ,f,n, y)))
            - sum(qProcessFuelDemand[i, ρ, f,o, n, y] for ρ in processes, o in outputs if haskey(qProcessFuelDemand, (i, ρ, f,o, n, y)))
            <= rFuelBalanceConstraint[i,f,n,y] * BIG
)

# R Fuel Balance
@constraint(m, FuelBalanceConstraint3[i in industries, f in fuels, n in nodes, y in years; FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
            μFuelBalance[i,f,n,y] <= (1- rFuelBalanceConstraint[i,f,n,y]) * BIG 
)


######################################################### FuelDemandConstraint : μProcessesFuelDemand[c,ρ,f,n,y] -- Single Input Constraint
@variable(m, rFuelDemandConstraint[i in industries, ρ in processes, f in fuels,o in outputs, n in nodes,y in years;  
                haskey(iNm,(n,i)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[i,ρ]==1 && iLm[i]==0], Bin)

@constraint(m, FuelDemandConstraint[i in industries, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[i,ρ]==1 &&  sFuelSwitching[ρ,f]==0 && iLm[i]==0 && FuelUse[f,i]==1],
                0<= qProcessFuelDemand[i,ρ,f,o,n,y] - qProcess[i,ρ,o,n,y] * sI[ρ,f,o,y]
                )

@constraint(m, FuelDemandConstraint2[i in industries, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[i,ρ]==1 &&  sFuelSwitching[ρ,f]==0 && iLm[i]==0 && FuelUse[f,i]==1],
                qProcessFuelDemand[i,ρ,f,o,n,y] - qProcess[i,ρ,o,n,y] * sI[ρ,f,o,y] <= BIG * rFuelDemandConstraint[i,ρ,f,o,n,y]
                )

@constraint(m, FuelDemandConstraint3[i in industries, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[i,ρ]==1 &&  sFuelSwitching[ρ,f]==0 && iLm[i]==0 && FuelUse[f,i]==1],
                μProcessesFuelDemand[i,ρ,f,o,n,y] <= BIG * (1-rFuelDemandConstraint[i,ρ,f,o,n,y]))
      
######################################################### FuelDemandConstraint : μProcessesFuelDemand[c,ρ,f,n,y] -- Fuel Switching Constraint
@variable(m, rFuelSwitchConstraintDual[i in industries, ρ in processes,o in outputs, n in nodes,y in years; 
                haskey(iNm,(n,i)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 for f in fuels)  && pIm[i,ρ]==1 && iLm[i]==0], Bin)

@constraint(m, FuelSwichtingConstraintDual[i in industries,ρ in processes,o in outputs,n in nodes, y in years; 
            haskey(iNm,(n,i)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[i,ρ]==1 for f in fuels)  && pIm[i,ρ]==1 && iLm[i]==0],
            0<= sum( 1/ sI[ρ,f,o,y] *qProcessFuelDemand[i,ρ,f,o,n,y] for f in fuels if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[i,ρ]==1) - qProcess[i,ρ,o,n,y]
)

@constraint(m, FuelSwichtingConstraintDual2[i in industries,ρ in processes,o in outputs,n in nodes, y in years; 
            haskey(iNm,(n,i)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && haskey(pFm, (ρ,f) )&& pIm[i,ρ]==1 for f in fuels)  && pIm[i,ρ]==1 && iLm[i]==0],
            sum(1/ sI[ρ,f,o,y] * qProcessFuelDemand[i,ρ,f,o,n,y] for f in fuels if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[i,ρ]==1) - qProcess[i,ρ,o,n,y]
            <= BIG * rFuelSwitchConstraintDual[i,ρ,o,n,y]
            )

@constraint(m, FuelSwichtingConstraintDual3[i in industries,ρ in processes,o in outputs,n in nodes, y in years;
            haskey(iNm,(n,i)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[i,ρ]==1 for f in fuels)  && pIm[i,ρ]==1 && iLm[i]==0],
            μFuelSwitchingProcessFuelDemand[i,ρ,o,n,y] <= BIG * (1-rFuelSwitchConstraintDual[i,ρ,o,n,y] ))

   
######################################################### Emission constraint defining μCO2
@variable(m,rCO2Constraint[c in consumers,n in nodes,years; haskey(iNm, (n,c))],Bin)

@constraint(m, EmissionConstraint[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                0<= qCO2ExMarket[c,n,y] 
                - sum(eF[ρ,o] * qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if haskey(eF,(ρ,o)) && pIm[c,ρ]==1 && haskey(qProcess,(c,ρ,o,n,y)))
)

@constraint(m, EmissionConstraint2[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                    qCO2ExMarket[c,n,y] 
                    - sum(eF[ρ,o] * qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if haskey(eF,(ρ,o)) && pIm[c,ρ]==1 && haskey(qProcess,(c,ρ,o,n,y)))      
                    <= rCO2Constraint[c,n,y]*BIG) 

@constraint(m, EmissionConstraint3[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                μCO2[c,n,y] <= (1 - rCO2Constraint[c,n,y]) *BIG)

######################################################### Duals: RFNBO Constraint defining μRFNBO
#@variable(m, rRfnboConstraint[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))], Bin)

#@constraint(m, RfnboConstraint[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],
#                0<= sum((rFm[ρ,f,y] - R[s,y] ) * qProcessFuelDemand[cc, ρ, f,o, n, y] for cc in consumers, f in fuels,ρ in processes, o in outputs, n in nodes
#                if haskey(qProcessFuelDemand, (cc, ρ, f,o, n, y)) && haskey(iNm,(n,cc)) && f∉["CO2", "CO", "N"] && haskey(sIm, (s,cc))))

#@constraint(m, RfnboConstraint2[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],
#                sum((rFm[ρ,f,y] - R[s,y] ) * qProcessFuelDemand[cc, ρ, f,o, n, y] for cc in consumers, f in fuels,ρ in processes, o in outputs, n in nodes
#                if haskey(qProcessFuelDemand, (cc, ρ, f,o, n, y)) && haskey(iNm,(n,cc)) && f∉["CO2", "CO", "N"] && haskey(sIm, (s,cc)))                      
#                    <= rRfnboConstraint[s,c,y] * BIG )
                        
#@constraint(m, RfnboConstraint3[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],
#                        μRFNBO[c,s,y] <= (1-rRfnboConstraint[s,c,y]) * BIG)


######################################################### Capacity Constraint: μProcessCapacity[c,ρ,n,y]
@variable(m, rCapacityConstraint[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],Bin)

@constraint(m, CapacityConstraint[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
                0<= qProcessCapacity[i,ρ,n,y] - sum(qProcess[i,ρ,o,n,y] for o in outputs if any(haskey(sI, (ρ,f, o, y)) for f in fuels)))

@constraint(m, CapacityConstraint2[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
                    qProcessCapacity[i,ρ,n,y] - sum(qProcess[i,ρ,o,n,y] for o in outputs if any(haskey(sI, (ρ,f, o, y)) for f in fuels)) <= rCapacityConstraint[i,ρ,n,y] *BIG)

@constraint(m, CapacityConstraint3[i in industries,ρ in processes,n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
                qProcessCapacity[i,ρ,n,y] <= (1-rCapacityConstraint[i,ρ,n,y]) *BIG)

######################################################### Capacity Constraint: μCapacityFunction
@variable(m, rAccCapacityConstraint[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],Bin)

@constraint(m, CapacityAccountingFunction[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
        0<= sum(qNewCapacity[i,ρ,n,yy] for yy in years if yy<=y && yy - y <= TechnologyLifetime[ρ])  + ResCap[i,ρ,n,y]
        - qProcessCapacity[i,ρ,n,y]
)  
 
@constraint(m, CapacityAccountingFunction2[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
        sum(qNewCapacity[i,ρ,n,yy] for yy in years if yy<=y && yy - y <= TechnologyLifetime[ρ])  + ResCap[i,ρ,n,y]
        - qProcessCapacity[i,ρ,n,y]
       <= rAccCapacityConstraint[i,ρ,n,y] * BIG
)  

@constraint(m, CapacityAccountingFunction3[i in industries,ρ in processes, n in nodes,y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
            μCapacityAccumulation[i,ρ,n,y]   <= (1-rAccCapacityConstraint[i,ρ,n,y]) * BIG
)  

######################################################### Export Duals 
### Export Import Balance
@variable(m, rExportImportBalance[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c)) && iLm[p]==0],Bin
)

@constraint(m, ExportImportBalance11[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
                FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c)) && iLm[p]==0], 
               0<= (1 - adj[n][nn][mode] * transportLosses[f,mode]/100) * qFuelExports[p, c, f, n, nn, mode, y]
               -qFuelImports[c, p, f, nn, n, mode, y]
            )

@constraint(m, ExportImportBalance2[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
                FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c)) && iLm[p]==0], 
                (1 - adj[n][nn][mode] * transportLosses[f,mode]/100) * qFuelExports[p, c, f, n, nn, mode, y]
                -qFuelImports[c, p, f, nn, n, mode, y]
                <= rExportImportBalance[p,c,f,n,nn,mode,y] * BIG
            )

@constraint(m, ExportImportBalance3[p in producers_ports, c in consumers_ports, f in traded_fuels,n in nodes, nn in nodes, mode in modes, y in years;
            FuelUse[f,p]==1 && transportFuelMap[mode,f]==1 && adj[n][nn][mode]>0 && haskey(iNm,(n,p)) && haskey(iNm, (nn,c)) && iLm[p]==0],
            μExportImportBalance[p,c,f,n,nn,mode,y]  <= rExportImportBalance[p,c,f,n,nn,mode,y] * BIG
        )

### Export Capacity Constraint
@variable(m, rExportCapacityConstraints[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],Bin)

@constraint(m,ExportCapacityConstraints[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],
0 <=  qExportAccCapacity[p, c, f, n, nn, mode, y] - qFuelExports[p, c, f, n, nn, mode, y]
)   

@constraint(m,ExportCapacityConstraints2[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],
qExportAccCapacity[p, c, f, n, nn, mode, y] - qFuelExports[p, c, f, n, nn, mode, y]
<= rExportCapacityConstraints[p,c,f,n,nn,mode,y] * BIG
)  

@constraint(m,ExportCapacityConstraints3[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],
μExportCapacity[p,c,f,n,nn,mode,y] <= (1-rExportCapacityConstraints[p,c,f,n,nn,mode,y])*BIG
)   

### Export Capacity Counting
@variable(m, rExportCapacityAccountingFunction[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],Bin)

@constraint(m, ExportCapacityAccountingFunction[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],
                0<= sum(qExportNewCapacity[p, c, f, n, nn, mode, yy] for yy in years if yy<=y && yy - y <= ExportLifeTime[mode,f]) 
                - qExportAccCapacity[p, c, f, n, nn, mode, y]
                ) 

@constraint(m, ExportCapacityAccountingFunction2[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],
                sum(qExportNewCapacity[p, c, f, n, nn, mode, yy] for yy in years if yy<=y && yy - y <= ExportLifeTime[mode,f]) 
                - qExportAccCapacity[p, c, f, n, nn, mode, y]
                <= rExportCapacityAccountingFunction[p,c,f,n,nn,mode,y] * BIG
                ) 

@constraint(m, ExportCapacityAccountingFunction3[p in producers_ports, c in consumers_ports, f in traded_fuels, n in nodes, nn in nodes, mode in modes, y in years;
                haskey(iNm, (n, p)) && haskey(iNm, (nn, c)) && (adj[n][nn][mode]>0)  && haskey(sFm, (p,f)) && transportFuelMap[mode,f]==1 && iLm[p]==0],
                μExportCapacityAccFunction[p,c,f,n,nn,mode,y] <= (1-rExportCapacityAccountingFunction[p,c,f,n,nn,mode,y]) * BIG
)

### Export Constraint
@variable(m, rExportConstraint[p in producers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, p))  && haskey(sFm,(p,f)) && iLm[p]==0],Bin)

@constraint(m, ExportConstraint[p in producers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, p))  && haskey(sFm,(p,f)) && iLm[p]==0],
                0<= 
                sum(qFuelExports[p,c,f,n,nn,mode,y] for c in consumers_ports, nn in nodes, mode in modes 
                    if adj[n][nn][mode]>0 && transportFuelMap[mode,f]==1 && FuelUse[f,c]==1  && haskey(iNm,(nn,c)))
                -
                sum(qFuelSold[p,c,f,n,nn,y] for c in consumers, nn in nodes if FuelUse[f,c]==1 && haskey(iNm,(nn,c)))
)

@constraint(m, ExportConstraint2[p in producers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, p))  && haskey(sFm,(p,f)) && iLm[p]==0],
                sum(qFuelExports[p,c,f,n,nn,mode,y] for c in consumers_ports, nn in nodes, mode in modes 
                    if adj[n][nn][mode]>0 && transportFuelMap[mode,f]==1 && FuelUse[f,c]==1  && haskey(iNm,(nn,c)))
                -
                sum(qFuelSold[p,c,f,n,nn,y] for c in consumers, nn in nodes if FuelUse[f,c]==1 && haskey(iNm,(nn,c)))
                <= rExportConstraint[p,f,n,y] * BIG
)

@constraint(m, ExportConstraint3[p in producers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, p))  && haskey(sFm,(p,f)) && iLm[p]==0],
                μExportConstraint[p,f,n,y] <= (1-rExportConstraint[p,f,n,y]) * BIG
                )

### Import Constraint
@variable(m, rImportConstraint1[c in consumers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, c))  && FuelUse[f,c]==1],Bin)

@constraint(m, ImportConstraint[c in consumers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, c)) && FuelUse[f,c]==1],
                0<= 
                sum(qFuelPurchased[c,p,f,n,nn,y] for p in producers, nn in nodes if haskey(sFm,(p,f)) && haskey(iNm,(nn,p)))
                - sum(qFuelImports[c,p,f,n,nn,mode,y] for p in producers_ports, nn in nodes, mode in modes 
                    if adj[nn][n][mode]>0 && transportFuelMap[mode,f]==1 && haskey(sFm,(p,f))  && haskey(iNm,(nn,p)))
)

@constraint(m, ImportConstraint2[c in consumers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, c)) && FuelUse[f,c]==1],
                sum(qFuelPurchased[c,p,f,n,nn,y] for p in producers, nn in nodes if haskey(sFm,(p,f)) && haskey(iNm,(nn,p)))
                - sum(qFuelImports[c,p,f,n,nn,mode,y] for p in producers_ports, nn in nodes, mode in modes 
                    if adj[nn][n][mode]>0 && transportFuelMap[mode,f]==1 && haskey(sFm,(p,f))  && haskey(iNm,(nn,p)))
                <= rImportConstraint1[c,f,n,y] * BIG
)


@constraint(m, ImportConstraint3[c in consumers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, c)) && FuelUse[f,c]==1],
                μImportConstraint[c,f,n,y] <= (1-rImportConstraint1[c,f,n,y]) * BIG
                )


#### Monetary Clearing Function
@variable(m,rMarketClearing[p in producers,c in consumers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],Bin)

@constraint(m, MarketClearing[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                0<= qFuelSold[p,c,f,nn,n,y] - qFuelPurchased[c,p,f,n,nn,y,]
                )

@constraint(m, MarketClearing2[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                qFuelSold[p,c,f,nn,n,y] - qFuelPurchased[c,p,f,n,nn,y,]  <= rMarketClearing[p,c,f,n,nn,y] * BIG
                )

@constraint(m, MarketClearing31[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                λ[c,p,f,n,nn,y] <= (1-rMarketClearing[p,c,f,n,nn,y]) * BIG
                )




######################################################### Hard Constraint Lower Level
@constraint(m, HardFuelDemandConstraint[i in industries, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[i,ρ]==1 &&  sFuelSwitching[ρ,f]==0 && iLm[i]==0 && FuelUse[f,i]==1],
                qProcessFuelDemand[i,ρ,f,o,n,y] == qProcess[i,ρ,o,n,y] * sI[ρ,f,o,y]
                )

@constraint(m, HardDemandConstraint[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
                sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
                 == D[c,g,n,y] 
                )

@constraint(m, HardFuelSwichtingConstraintDual2[i in industries,ρ in processes,o in outputs,n in nodes, y in years; 
                haskey(iNm,(n,i)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[i,ρ]==1 for f in fuels)  && pIm[i,ρ]==1 && iLm[i]==0],
                sum(1/ sI[ρ,f,o,y] * qProcessFuelDemand[i,ρ,f,o,n,y] for f in fuels if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[i,ρ]==1) == qProcess[i,ρ,o,n,y]
                )


@constraint(m, HardPhysicalEndoFuelBalanceConstraint1[i in industries_ports, f in traded_fuels, n in nodes, y in years; 
                FuelUse[f,i]==1 && haskey(iNm,(n,i)) && iLm[i]==0],
                sum(qFuelImports[i, p, f, n, nn, mode, y]
                for p in producers_ports, nn in nodes, mode in modes 
                if haskey(qFuelImports, (i, p, f, n, nn,mode, y)))
                + sum(qProcess[i,ρρ,f,n, y] for ρρ in processes if haskey(qProcess, (i,ρρ,f,n, y)))
                ==
                 sum(qFuelExports[i, c, f, n, nn, mode, y]
                for  c in consumers_ports, nn in nodes, mode in modes
                if haskey(qFuelExports, (i, c, f, n, nn, mode, y)))  
                +sum(qProcessFuelDemand[i, ρ, f,o,n,y] for ρ in processes, o in outputs  if pIm[i,ρ]==1 && haskey(sI, (ρ,f,o,y)))
                )
                
@constraint(m, HardMarketClearing[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                qFuelSold[p,c,f,nn,n,y] == qFuelPurchased[c,p,f,n,nn,y,] 
                )   

@constraint(m, HardEmission2[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                qCO2ExMarket[c,n,y] 
                == sum(eF[ρ,o] * qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if haskey(eF,(ρ,o)) && pIm[c,ρ]==1 && haskey(qProcess,(c,ρ,o,n,y)))      
                ) 

@constraint(m, HardImportConstraint[c in consumers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, c)) && FuelUse[f,c]==1],
                0== 
                sum(qFuelPurchased[c,p,f,n,nn,y] for p in producers, nn in nodes if haskey(sFm,(p,f)) && haskey(iNm,(nn,p)))
                - sum(qFuelImports[c,p,f,n,nn,mode,y] for p in producers_ports, nn in nodes, mode in modes 
                    if adj[nn][n][mode]>0 && transportFuelMap[mode,f]==1 && haskey(sFm,(p,f))  && haskey(iNm,(nn,p)))
)


@constraint(m, HardExportConstraint[p in producers, f in traded_fuels, n in nodes, y in years; haskey(iNm, (n, p))  && haskey(sFm,(p,f))],
                0<= 
                sum(qFuelExports[p,c,f,n,nn,mode,y] for c in consumers_ports, nn in nodes, mode in modes 
                    if adj[n][nn][mode]>0 && transportFuelMap[mode,f]==1 && FuelUse[f,c]==1  && haskey(iNm,(nn,c)))
                -
                sum(qFuelSold[p,c,f,n,nn,y] for c in consumers, nn in nodes if FuelUse[f,c]==1 && haskey(iNm,(nn,c)))
)

################################### Objective Function
cH2 = 1000      # EUR/t H2 ~ 1 EUR/kg

@objective(m, Max, sum((λ[c,p,f,n,nn,y]-cH2) * qFuelSold[p,c,f,nn,n,y] for c in consumers,p in producers, n in nodes, nn in nodes, y in years, f in traded_fuels 
                if haskey(iNm,(nn,p))  &&  haskey(iNm,(n,c)) &&  FuelUse[f,c]==1 && iLm[p]==1 && haskey(sFm,(p,f))))

set_optimizer(m,Gurobi.Optimizer)
set_optimizer_attribute(m, "IntFeasTol", 1e-9)
set_optimizer_attribute(m, "InfUnbdInfo", 1)
set_optimizer_attribute(m, "LazyConstraints", true)
set_optimizer_attribute(m, "MIPFocus", 1)
set_optimizer_attribute(m, "Heuristics", 0.2)
set_optimizer_attribute(m, "MIPGap", 0.10)

optimize!(m)




compute_conflict!(m)

# Define function and set types to loop through
function_types = [JuMP.AffExpr]  # Using Affine expressions as an example
set_types = [MOI.LessThan{Float64}, MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}]  # Concrete types for constraint sets

# Loop through all constraints in the model by function type and set type
for f_type in function_types
    for s_type in set_types
        for con in all_constraints(m, f_type, s_type)
            # Check if the constraint is part of the IIS (conflict)
            if MOI.get(m, MOI.ConstraintConflictStatus(), con) != MOI.NOT_IN_CONFLICT
                println("Constraint $(con) is part of the IIS")
            end
        end
    end
end


HardPhysicalEndoFuelBalanceConstraint1["Hvc", "H2","Leverkusen",2050]

value.(λ)/(1e9)/1000

value.(qFuelSold)
value.(qProcess)

#value.(qImports)
value.(qProcessFuelDemand)
value.(qFuelPurchased)
#value.(qImports)
value.(rFuelDemandConstraint)
value.(μCO2)
value.(qProcessFuelDemand)
value.(qFuelPurchased)

value.(μFuelBalance)

value.(qCO2ExMarket)
value.(μProcessCapacity)
value.(qAccCapacity)

value.(rNewCapacityFoc)
value.(qNewCapacity)


value.(rCapacityConstraint)
value.(qProcessFuelDemand)
eA

qAccCapacity
value.(qCO2)
eA["Hvc",2030] .* 1050
value.(qAccCapacity["Hvc","Nto/Nta","Leverkusen",2030])

value.(qImports)
value.(λCO2)

value.(qCO2ExMarket)
value.(qProcess)
value.(qImports)

value.(λCO2)

value.(qCO2ExMarket)
#Shaddow Prices
value.(μFuelBalance)
value.(μProcessesFuelDemand)
value.(μProcessCapacity)
value.(μCO2)

# Binaries
value.(rDemandConstraint)
value.(rProcessFuelDemandFoc)
value.(rqFuelPurchasedFoc)
value.(rFuelDemandConstraint)
value.(rNewCapacityFoc)
value.(rImports)
value.(rqFuelPurchasedFoc)