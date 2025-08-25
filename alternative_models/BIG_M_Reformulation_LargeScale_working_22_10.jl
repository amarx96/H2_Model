# Setting up the Modeling Environment 
using Gurobi
using JuMP
using Revise


include("_DataImport.jl")
iLm,pIm,pFm, iNm, finalGoodProcessMap, rFm, FuelUse, P, sO, sI, sFm, K,ExportK, ResCap,Opex, R, D, sFuelSwitching, TechnologyLifetime,ExportLifeTime,sIm,eF,eA,pip_adj,shp_adj,sub_adj,transportLosses, transportFuelMap,pImports,importGoods,CO2Price, outputs,processes,fuels,cF,FOM,ExportFOM = import_data()



include("_MarketSetUp.jl")
market_data =  market_setup(    consumers=["Aviation"],
                                nodes=["Hamburg","Chanaral","Teruel","Frankfurt", "Fiska"],
                                years=[2050],
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
BIG = 1e9




################################### Describing the lower Level ############################################
# Demand Constraint 
################################### Variable
@variable(m,qProcess[i in industries_ports,ρ in processes, o in outputs, n in nodes, y in years; 
                    haskey(iLm,(n,i)) && pIm[i,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels if haskey(pFm, (f,ρ)))]>=0
)

@variable(m,qProcessFuelDemand[i in industries_ports, ρ in processes,f in fuels,o in outputs, n in nodes, y in years;
                    haskey(iLm,(n,i)) && pIm[i,ρ]==1 && haskey(sI,(ρ,f,o,y))]>=0)

@variable(m,qFuelPurchased[i in vcat(consumers, ["LC Producer"]),p in producers_markets, f in fuels,n in nodes,nn in nodes_markets,y in years; 
                    FuelUse[f,i]==1 && haskey(iLm, (n,i))  && haskey(iLm,(n,i)) && haskey(iLm,(nn,p)) && haskey(sFm, (p,f))]
                    >=0)
                
                    
                

################################### w.r.t. qFuelPurchased -- Traded
@variable(m, λ[c in consumers,p in producers,f in traded_fuels, n in nodes,nn in nodes, y in years; 
                    FuelUse[f,c]==1 && haskey(iNm, (n,c)) && haskey(sFm, (p,f)) && sFm[p,f]==1 && haskey(iNm, (nn,p))]>=0)                
    
@variable(m, μEndoFuelBalance[c in consumers, f in traded_fuels,n in nodes,y in years; haskey(iNm, (n,c)) && FuelUse[f,c]==1]>=0)

@variable(m, μExoFuelBalance[c in consumers, f in traded_fuels,n in nodes,y in years; haskey(iNm, (n,c)) && FuelUse[f,c]==1]>=0)

@variable(m, rqFuelPurchasedFoc[c in consumers,p in producers_markets, f in fuels,n in nodes,nn in nodes_markets,y in years; 
                    FuelUse[f,c]==1 && haskey(iNm, (n,c))  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f))],
                    Bin)

################################### w.r.t. qFuelPurchased -- Traded                   
@constraint(m, FuelPurchasedFOC1[c in consumers,p in producers,f in traded_fuels,l in  locations,nn in nodes,  y in years; 
                        FuelUse[f,c]==1  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f))],
                        0<=   λ[c,p,f,n,nn,y] - μEndoFuelBalance[c,f,n,y])


@constraint(m, FuelPurchasedFOC2[c in consumers,p in producers,f in traded_fuels,l in  locations,nn in nodes,  y in years; #
                        FuelUse[f,c]==1 && haskey(iNm, (n,c))  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f))],
                        λ[c,p,f,n,nn,y] - μFuelBalance[c,f,n,y]<= rqFuelPurchasedFoc[c,p,f,n,nn,y]*BIG)


@constraint(m, FuelPurchasedFOC3[c in consumers,p in producers,f in traded_fuels,l in  locations,nn in nodes,  y in years;
                        FuelUse[f,c]==1 && haskey(iNm, (n,c))  && haskey(iNm,(n,c)) && haskey(iNm,(nn,p)) && haskey(sFm, (p,f))],
                        qFuelPurchased[c,p,f,n,nn,y] <= (1-rqFuelPurchasedFoc[c,p,f,n,nn,y])*BIG)

                        non_traded_fuels
################################### w.r.t. qFuelPurchased -- Non Trade
@constraint(m, FuelPurchasedFocNonTraded[c in consumers,f in non_traded_fuels ,n in nodes,y in years;
                        FuelUse[f,c]==1 && haskey(iNm,(n,c))],
                        0<=   P[f,y]  -  μFuelBalance[c,f,n,y] )



@constraint(m, FuelPurchasedFocNonTraded2[c in consumers,f in non_traded_fuels ,n in nodes,y in years;
                    FuelUse[f,c]==1 && haskey(iNm,(n,c))  && haskey(iNm,(n,c))],
                        P[f,y]  - μFuelBalance[c,f,n,y] <= rqFuelPurchasedFoc[c,"Market",f,n,"Local",y]*BIG
                        )



@constraint(m, FuelPurchasedFocNonTraded4[c in consumers,f in non_traded_fuels ,n in nodes,y in years;
                        FuelUse[f,c]==1 && haskey(iNm,(n,c))  && haskey(iNm,(n,c))],
                        qFuelPurchased[c,"Market",f,n,"Local",y] <= (1-rqFuelPurchasedFoc[c,"Market",f,n,"Local",y])*BIG)


################################### w.r.t. qProcessFuelDemand
@variable(m, μProcessesFuelDemand[c in consumers,ρ in processes,f in fuels,o in outputs,n in nodes,y in years; 
                    haskey(iNm, (n,c)) && pIm[c,ρ]==1 && haskey(sI,(ρ,f,o,y))]
                    >=0)
                    
@variable(m, μFuelSwitchingProcessFuelDemand[c in consumers,ρ in processes,o in outputs,n in nodes,y in years; 
                    haskey(iNm,(n,c)) && pIm[c,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels)
                    ]>=0)

@variable(m, μRFNBO[c in consumers,s in sectors,y in years; haskey(sIm, (s,c))]>=0)

@variable(m, rProcessFuelDemandFoc[c in consumers,ρ in processes,f in fuels,o in outputs, l in  locations,y in years;
            pIm[c,ρ]==1  && haskey(iNm,(n,c)) && haskey(sI,(ρ,f,o,y))], Bin)


@constraint(m, ProcessFuelDemand[c in consumers,ρ in processes, f in fuels,o in outputs,l in  locations,y in years;
                        pIm[c,ρ]==1  && haskey(iNm,(n,c)) && haskey(sI,(ρ,f,o,y))],
                         0<= μFuelBalance[c,f,n,y] 
                         - sum((R[s,y] - rFm[f,y])*μRFNBO[c,s,y] for s in sectors if  haskey(sIm, (s,c)) && f∉["CO2", "CO", "N"])  # RFNBO
                         - (1- sFuelSwitching[ρ,f]) * μProcessesFuelDemand[c,ρ,f,o,n,y]
                         - sFuelSwitching[ρ,f] * μFuelSwitchingProcessFuelDemand[c,ρ,o,n,y] 
                         )


@constraint(m, ProcessFuelDemand2[c in consumers,ρ in processes,f in fuels, o in outputs, l in  locations,y in years;
                        pIm[c,ρ]==1  && haskey(iNm,(n,c)) && haskey(sI,(ρ,f,o,y))],
                        μFuelBalance[c,f,n,y] 
                        - sum((R[s,y] - rFm[f,y])*μRFNBO[c,s,y] for s in sectors if  haskey(sIm, (s,c)) && f∉["CO2", "CO", "N"])  # RFNBO
                        - (1- sFuelSwitching[ρ,f]) * μProcessesFuelDemand[c,ρ,f,o,n,y]
                        - sFuelSwitching[ρ,f] * μFuelSwitchingProcessFuelDemand[c,ρ,o,n,y] 
                        <= rProcessFuelDemandFoc[c,ρ,f,o,n,y]*BIG)

          
@constraint(m, ProcessFuelDemand3[c in consumers,ρ in processes,f in fuels,o in outputs,l in  locations,y in years;
                        pIm[c,ρ]==1  && haskey(iNm,(n,c)) && haskey(sI,(ρ,f,o,y))],
                         qProcessFuelDemand[c,ρ,f,o,n,y] <= (1-rProcessFuelDemandFoc[c,ρ,f,o,n,y])*BIG)
     
################################### w.r.t. qProcesses
@variable(m, λFGMC[c in consumers, g in goods, n in nodes, y  in years; haskey(D,(c,g,n,y)) && haskey(iNm,(n,c))])
@variable(m, rProcessFOC[c in consumers,ρ in processes,o in outputs, n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels)], Bin)
@variable(m, μCO2[c in consumers,n in nodes,years; haskey(iNm, (n,c))]>=0)#
@variable(m, μProcessCapacity[c in consumers, ρ in processes, n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1])

@constraint(m, ProcessFoc[c in consumers, ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels)],
                0<=
                Opex[ρ,y] + μProcessCapacity[c,ρ,n,y]
                + sum( (1- sFuelSwitching[ρ,f])  * μProcessesFuelDemand[c,ρ,f,o,n,y] * sI[ρ,f,o,y] 
                + sFuelSwitching[ρ,f]   *   μFuelSwitchingProcessFuelDemand[c,ρ,o,n,y] * sI[ρ,f,o,y] for f in fuels if haskey(sI, (ρ,f,o,y)))
                +  eF[ρ,o] *  μCO2[c,n,y]
                - (haskey(μFuelBalance, (c, o, l, y)) ? μFuelBalance[c, o, l, y] : 0)  # Check for existence, else use 0
                - sum(λFGMC[c,g,n,y] for g in goods if g==o) 
                )
  

@constraint(m, ProcessFoc2[c in consumers, ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels)],
                Opex[ρ,y] + μProcessCapacity[c,ρ,n,y]
                + sum( (1- sFuelSwitching[ρ,f])  * μProcessesFuelDemand[c,ρ,f,o,n,y] * sI[ρ,f,o,y] 
                + sFuelSwitching[ρ,f]   *   μFuelSwitchingProcessFuelDemand[c,ρ,o,n,y] * sI[ρ,f,o,y]  for f in fuels if haskey(sI, (ρ,f,o,y)))
                +  eF[ρ,o] *  μCO2[c,n,y]
                - (haskey(μFuelBalance, (c, o, l, y)) ? μFuelBalance[c, o, l, y] : 0)  # Check for existence, else use 0
                - sum(λFGMC[c,g,n,y] for g in goods if g==o)
            <= rProcessFOC[c,ρ,o,n,y] * BIG
            )

@constraint(m, ProcessFoc3[c in consumers, ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1 && any(haskey(sI,(ρ,f,o,y)) for f in fuels)],
            qProcess[c,ρ,o,n,y] <= (1 - rProcessFOC[c,ρ,o,n,y]) * BIG
            )


################################### w.r.t. Acc Capacity : qAccCapacity[c,ρ,n,y]
@variable(m, qAccCapacity[i in industries_ports,ρ in processes,n in nodes, y in years;pIm[i,ρ]==1 && haskey(iNm,(n,i))]>=0)
@variable(m, μCapacityFunction[c in consumers, ρ in processes, n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1]>=0)
@variable(m, rCapacityAccFoc[c in consumers, ρ in processes, n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ]==1],Bin)

@constraint(m,  CapacityAccFoc[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1],
                0<= μCapacityFunction[c,ρ,n,y]  - μProcessCapacity[c,ρ,n,y]
            )

@constraint(m,  CapacityAccFoc2[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1],
                    μCapacityFunction[c,ρ,n,y]   - μProcessCapacity[c,ρ,n,y] <= rCapacityAccFoc[c,ρ,n,y]*BIG
        )

@constraint(m,  CapacityAccFoc31[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1],
                qAccCapacity[c,ρ,n,y] <= (1-rCapacityAccFoc[c,ρ,n,y])*BIG
)


################################### w.r.t. New Capacity
@variable(m, rNewCapacityFoc[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1], Bin)
@variable(m, qNewCapacity[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1]>=0)


@constraint(m, NewCapacityFoc[c in consumers, ρ in processes, n in nodes, y in years; haskey(iNm,(n,c)) && pIm[c,ρ] == 1],
                        0 <=  K[ρ,y] - sum(μCapacityFunction[c,ρ,n,yy] for yy in years if yy>=y && yy - y <= TechnologyLifetime[ρ])
)


@constraint(m,  NewCapacityFoc2[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1],
                        K[ρ,y] - sum(μCapacityFunction[c,ρ,n,yy] for yy in years if yy>=y && yy - y <= TechnologyLifetime[ρ]) <= rNewCapacityFoc[c,ρ,n,y]*BIG
        )

@constraint(m,  NewCapacityFoc3[c in consumers, ρ in processes, n in nodes, y in years;haskey(iNm,(n,c)) && pIm[c,ρ]==1],
                qNewCapacity[c,ρ,n,y] <= (1-rNewCapacityFoc[c,ρ,n,y])*BIG
)


################################### w.r.t. Emission qCO2
@variable(m, qCO2[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))]>=0)
@variable(m, λCO2[y in years]>=0)
@variable(m, rCO2[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))]>=0)

@constraint(m, EmissionFoc[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))],
            0<=    λCO2[y] - μCO2[c,n,y]         
)

@constraint(m, EmissionFoc2[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))],
            λCO2[y] - μCO2[c,n,y]     <= rCO2[c,n,y]*BIG     
)

@constraint(m, EmissionFoc3[c in consumers, n in nodes, y in years; haskey(iNm, (n,c))],
            qCO2[c,n,y]    <= (1-rCO2[c,n,y])*BIG     
)

################################### Additional Carbon Purchased
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

################################### w.r.t. qImports
#@variable(m, qImports[c in consumers,g in importGoods, n in nodes, y in years; haskey(iNm, (n,c)) && haskey(pImports, (c,g,y))]>=0)
#@variable(m, rImports[c in consumers,g in importGoods, n in nodes, y in years; haskey(iNm, (n,c)) && haskey(pImports, (c,g,y))]>=0)


#@constraint(m,  ImportFoc1[c in consumers, g in importGoods,gg in goods,n in nodes, y in years;
#                haskey(iNm, (n,c)) &&  haskey(pImports, (c,g,y)) && haskey(Q,(c,gg,n,y)) && haskey(finalGoodProcessMap, g) && finalGoodProcessMap[g]==gg],
#                0<= pImports[c,g,y] + eF[g] * μCO2[c,n,y]   - λFGMC[c,gg,n,y]  
#        )

#@constraint(m,  ImportFoc2[c in consumers, g in importGoods,gg in goods,n in nodes, y in years;
#        haskey(iNm, (n,c)) &&  haskey(pImports, (c,g,y)) && haskey(Q,(c,gg,n,y)) && haskey(finalGoodProcessMap, g) && finalGoodProcessMap[g]==gg],
#        pImports[c,g,y] + eF[g] * μCO2[c,n,y]  - λFGMC[c,gg,n,y] <= rImports[c,g,n,y] * BIG    
#)

#@constraint(m,  ImportFoc3[c in consumers, g in importGoods,gg in goods,n in nodes, y in years;
#        haskey(iNm, (n,c)) &&  haskey(pImports, (c,g,y)) && haskey(Q,(c,gg,n,y)) && haskey(finalGoodProcessMap, g) && finalGoodProcessMap[g]==gg],
#        qImports[c,g,n,y] <= (1 - rImports[c,g,n,y]) * BIG
#)


################################### Lower Level Duals ############################################# consumers
# Demand Constraint : defining λFGMC[c,g,n,y]
@variable(m, rDemandConstraint[c in consumers, g in goods, n in nodes, y in years;haskey(D,(c,g,n,y)) && haskey(iNm,(n,c))],Bin)

@constraint(m, DemandConstraint11[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
            0 <= sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
            # - sum(qImports[c,gg,n,y] for gg in importGoods if haskey(iNm, (n,c)) &&  haskey(pImports, (c,gg,y)) && finalGoodProcessMap[gg]==g)
             - D[c,g,n,y] 
            )


@constraint(m, DemandConstraint21[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
            sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
            # - sum(qImports[c,gg,n,y] for gg in importGoods if haskey(iNm, (n,c)) &&  haskey(pImports, (c,gg,y)) && finalGoodProcessMap[gg]==g)
             - D[c,g,n,y] 
            <= rDemandConstraint[c,g,n,y] * BIG
            )

@constraint(m, DemandConstraint31[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
                λFGMC[c,g,n,y]  <= (1 - rDemandConstraint[c,g,n,y]) * BIG
            )
   


######################################################### Fuel Balance Constraint : μFuelBalance
@variable(m, rFuelBalanceConstraint[c in consumers, f in fuels, n in nodes, y in years;  FuelUse[f,c]==1 && haskey(iNm,(n,c))], Bin)

@constraint(m, FuelBalanceConstraint11[c in consumers, f in fuels, n in nodes, y in years; FuelUse[f,c]==1 && haskey(iNm,(n,c))],
        0<= sum(qFuelPurchased[c,p, f, l,nn, y] for p in producers_markets, nn in nodes_markets if haskey(sFm, (p,f)) && haskey(iNm, (nn,p)) )  
            + sum(qProcess[c,ρρ,f,n, y] for ρρ in processes if haskey(sO, (ρρ,f, y)) && pIm[c,ρρ]==1)
            - sum(qProcessFuelDemand[c, ρ, f,o, l, y] for ρ in processes, o in outputs  if pIm[c,ρ]==1 && haskey(sI, (ρ,f,o,y)))
        )

@constraint(m, FuelBalanceConstraint2[c in consumers, f in fuels, n in nodes, y in years; FuelUse[f,c]==1 && haskey(iNm,(n,c))],
            sum(qFuelPurchased[c,p, f, l,nn, y] for p in producers_markets, nn in nodes_markets if haskey(sFm, (p,f)) && haskey(iNm, (nn,p)) )  
            + sum(qProcess[c,ρρ,f,n, y] for ρρ in processes if haskey(sO, (ρρ,f, y)) && pIm[c,ρρ]==1)
            - sum(qProcessFuelDemand[c, ρ, f,o, l, y] for ρ in processes, o in outputs  if pIm[c,ρ]==1 && haskey(sI, (ρ,f,o,y)))
        <=rFuelBalanceConstraint[c,f,n,y] * BIG)
        
@constraint(m, FuelBalanceConstraint3[c in consumers, f in fuels, n in nodes, y in years; FuelUse[f,c]==1 && haskey(iNm,(n,c))],
                μFuelBalance[c,f,n,y] <= (1- rFuelBalanceConstraint[c,f,n,y]) * BIG 
)


######################################################### FuelDemandConstraint : μProcessesFuelDemand[c,ρ,f,n,y] -- Single Input Constraint
@variable(m, rFuelDemandConstraint[c in consumers, ρ in processes, f in fuels,o in outputs, n in nodes,y in years;  haskey(iNm,(n,c)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[c,ρ]==1], Bin)

@constraint(m, FuelDemandConstraint12[c in consumers, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[c,ρ]==1 &&  sFuelSwitching[ρ,f]==0],
    0<= qProcessFuelDemand[c,ρ,f,o,n,y] - qProcess[c,ρ,o,n,y] * sI[ρ,f,o,y])

@constraint(m, FuelDemandConstraint2[c in consumers, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[c,ρ]==1 && sFuelSwitching[ρ,f]==0],
    qProcessFuelDemand[c,ρ,f,o,n,y] - qProcess[c,ρ,o,n,y] * sI[ρ,f,o,y] <= BIG * rFuelDemandConstraint[c,ρ,f,o,n,y])

@constraint(m, FuelDemandConstraint4[c in consumers, ρ in processes,f in fuels,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[c,ρ]==1 && sFuelSwitching[ρ,f]==0],
                        μProcessesFuelDemand[c,ρ,f,o,n,y] <= BIG * (1-rFuelDemandConstraint[c,ρ,f,o,n,y]))
      
######################################################### FuelDemandConstraint : μProcessesFuelDemand[c,ρ,f,n,y] -- Fuel Switching Constraint
@variable(m, rFuelDemandConstraintDual2[c in consumers, ρ in processes,o in outputs, n in nodes,y in years; haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 for f in fuels)  && pIm[c,ρ]==1], Bin)

@constraint(m, FuelSwichtingConstraintDual[c in consumers,ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[c,ρ]==1 for f in fuels)  && pIm[c,ρ]==1],
    0<= sum( 1/ sI[ρ,f,o,y] *qProcessFuelDemand[c,ρ,f,o,n,y] for f in fuels if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[c,ρ]==1) - qProcess[c,ρ,o,n,y]
)

@constraint(m, FuelSwichtingConstraintDual2[c in consumers,ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[c,ρ]==1 for f in fuels)  && pIm[c,ρ]==1],
        sum(1/ sI[ρ,f,o,y] * qProcessFuelDemand[c,ρ,f,o,n,y] for f in fuels if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[c,ρ]==1) - qProcess[c,ρ,o,n,y]
        <= BIG * rFuelDemandConstraintDual2[c,ρ,o,n,y])

@constraint(m, FuelSwichtingConstraintDual3[c in consumers,ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[c,ρ]==1 for f in fuels)  && pIm[c,ρ]==1],
                μFuelSwitchingProcessFuelDemand[c,ρ,o,n,y] <= BIG * (1-rFuelDemandConstraintDual2[c,ρ,o,n,y] ))

   
######################################################### Emission constraint defining μCO2
@variable(m,rCO2Constraint[c in consumers,n in nodes,years; haskey(iNm, (n,c))],Bin)


@constraint(m, EmissionConstraint[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                0<= qCO2[c,n,y] + qCO2ExMarket[c,n,y] 
                - sum(eF[ρ,o] * qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if haskey(eF,(ρ,o)) && pIm[c,ρ]==1 && haskey(qProcess,(c,ρ,o,n,y)))
               # - sum(eF[g] * qImports[c,g,n,y] for g in importGoods if haskey(iNm, (n,c)) &&  haskey(pImports, (c,g,y)) && haskey(eF,g)))
)

@constraint(m, EmissionConstraint2[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                    qCO2[c,n,y] + qCO2ExMarket[c,n,y] 
                    - sum(eF[ρ,o] * qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if haskey(eF,(ρ,o)) && pIm[c,ρ]==1 && haskey(qProcess,(c,ρ,o,n,y)))
                    - sum(eF[g] * qImports[c,g,n,y] for g in importGoods if haskey(iNm, (n,c)) &&  haskey(pImports, (c,g,y)) && haskey(eF,g))         
                    <= rCO2Constraint[c,n,y]*BIG) 

@constraint(m, EmissionConstraint3[c in consumers,n in nodes, y in years; haskey(iNm,(n,c))],
                μCO2[c,n,y] <= (1 - rCO2Constraint[c,n,y]) *BIG)

######################################################### Duals: RFNBO Constraint defining μRFNBO
@variable(m, rRfnboConstraint[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))], Bin)

@constraint(m, RfnboConstraint[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],
                0<=sum(rFm[f,y] * qProcessFuelDemand[c, ρ, f,o, l, y] for c in consumers, f in fuels,ρ in processes, o in outputs, n in nodes 
                if haskey(qProcessFuelDemand, (c,ρ,f,o,n,y)) && haskey(iNm,(n,c)) && f∉["CO2", "CO", "N"])
                - R[s,y] * sum(qProcessFuelDemand[c, ρ, f, o,n, y] for f in fuels,ρ in processes, c in consumers, n in nodes, o in outputs
                if haskey(qProcessFuelDemand, (c,ρ,f,o,n,y)) && haskey(iNm,(n,c)) && f∉["CO2", "CO", "N", "Electricity"])
)


@constraint(m, RfnboConstraint2[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],
                    sum(qProcessFuelDemand[c, ρ, f, o,n, y] * rFm[f,y] for f in fuels,ρ in processes, o in outputs, c in consumers,  n in nodes 
                    if haskey(qProcessFuelDemand, (c,ρ,f,o,n,y)) && haskey(iNm,(n,c)) && f∉["CO2", "CO", "N"])
                    - R[s,y] * sum(qProcessFuelDemand[c, ρ, f, o,n, y] for f in fuels,ρ in processes, c in consumers, n in nodes, o in outputs
                    if haskey(qProcessFuelDemand, (c,ρ,f,o,n,y)) && haskey(iNm,(n,c)) && f∉["N", "CO2", "CO"])
                    <= rRfnboConstraint[s,c,y] * BIG )
                        
@constraint(m, RfnboConstraint3[s in sectors,c in consumers, y in years;haskey(sIm, (s,c))],
                        μRFNBO[c,s,y] <= (1-rRfnboConstraint[s,c,y]) * BIG)


######################################################### Capacity Constraint: μProcessCapacity[c,ρ,n,y]
@variable(m, rCapacityConstraint[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],Bin)

@constraint(m, CapacityConstraint[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],
                0<= qAccCapacity[c,ρ,n,y] - sum(qProcess[c,ρ,o,n,y] for o in outputs if any(haskey(sI, (ρ,f, o, y)) for f in fuels)))

@constraint(m, CapacityConstraint2[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],
                qAccCapacity[c,ρ,n,y] - sum(qProcess[c,ρ,o,n,y] for o in outputs if any(haskey(sI, (ρ,f, o, y)) for f in fuels)) <= rCapacityConstraint[c,ρ,n,y] *BIG)

@constraint(m, CapacityConstraint3[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],
                μProcessCapacity[c,ρ,n,y] <= (1-rCapacityConstraint[c,ρ,n,y]) *BIG)

######################################################### Capacity Constraint: μCapacityFunction
@variable(m, rAccCapacityConstraint[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],Bin)

@constraint(m, CapacityAccountingFunction[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],
        0<= sum(qNewCapacity[c,ρ,n,yy] for yy in years if yy<=y && y - yy <= TechnologyLifetime[ρ])  + ResCap[ρ,"GER",y]
        - qAccCapacity[c,ρ,n,y]
)  
 
@constraint(m, CapacityAccountingFunction2[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],
        sum(qNewCapacity[c,ρ,n,yy] for yy in years if yy<=y && y - yy <= TechnologyLifetime[ρ])  + ResCap[ρ,"GER",y]
        - qAccCapacity[c,ρ,n,y]
       <= rAccCapacityConstraint[c,ρ,n,y] * BIG
)  

@constraint(m, CapacityAccountingFunction4[c in consumers,ρ in processes, n in nodes,y in years;pIm[c,ρ]==1 && haskey(iNm,(n,c))],
                μCapacityFunction[c,ρ,n,y]   <= (1-rAccCapacityConstraint[c,ρ,n,y]) * BIG
)  


######################################################### Emission Market μCO2[c,n,y]
@variable(m, rλCO2[y in years],Bin)

@constraint(m, EmissionMarketConstraint1[y in years],
            0<= sum(eA[c,y] * D[c,g,n,y] for g in goods, c in consumers, n in nodes if haskey(iNm,(n,c)) && haskey(eA, (c,y)))
            - sum(qCO2[c,n,y] for c in consumers, n in nodes if haskey(iNm,(n,c))) 
)

@constraint(m,EmissionMarketConstraint5[y in years],
            sum(eA[c,y] * D[c,g,n,y] for g in goods, c in consumers, n in nodes if haskey(iNm,(n,c)) && haskey(eA, (c,y)))
            - sum(qCO2[c,n,y] for c in consumers, n in nodes if haskey(iNm,(n,c)))
                <= rλCO2[y] * BIG
)

@constraint(m,EmissionMarketConstraint4[y in years],
                λCO2[y]<= (1-rλCO2[y]) * BIG
)

######################################################### Hard Constraint Lower Level
@constraint(m, PhysicalDemandConstraint[c in consumers,g in goods, n in nodes, y in years; haskey(rDemandConstraint, (c,g,n,y))],
            0 == D[c,g,n,y] 
            - sum(qProcess[c,ρ,o,n,y] for ρ in processes, o in outputs if pIm[c,ρ]==1 && o==g &&  haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f,o,y)) for f in fuels))
            # - sum(qImports[c,gg,n,y] for gg in importGoods if haskey(iNm, (n,c)) &&  haskey(pImports, (c,gg,y)) && finalGoodProcessMap[gg]==g)
            )

            

@constraint(m, PhysicalFuelDemandConstraint[c in consumers, ρ in processes,f in fuels,o in outputs,n in nodes,y in years; haskey(iNm,(n,c)) && haskey(sI, (ρ,f, o, y)) && pFm[f,ρ]==1 && pIm[c,ρ]==1 &&  sFuelSwitching[ρ,f]==0],
            0== qProcessFuelDemand[c,ρ,f,o,n,y] - qProcess[c,ρ,o,n,y] * sI[ρ,f,o,y])
                


@constraint(m, PhysicalFuelSwichtingConstraintDual[c in consumers,ρ in processes,o in outputs,n in nodes, y in years; haskey(iNm,(n,c)) && any(haskey(sI, (ρ,f, o, y)) &&  sFuelSwitching[ρ,f]==1 && pFm[f,ρ]==1 && pIm[c,ρ]==1 for f in fuels)  && pIm[c,ρ]==1],
                sum( 1/ sI[ρ,f,o,y] * qProcessFuelDemand[c,ρ,f,o,n,y] for f in fuels if haskey(sI, (ρ,f, o, y)) && sFuelSwitching[ρ,f]==1 && pIm[c,ρ]==1) - qProcess[c,ρ,o,n,y] 
                == 0)

######################################################### Hydorgen Market
@variable(m,qFuelSold[p in  producers,c in consumers,f in traded_fuels,n in nodes,nn in nodes,y in years;
                (haskey(iNm,(n,p))) &&  haskey(sFm, (p,f)) && sFm[p,f]==1 && haskey(iNm,(nn,c)) && FuelUse[f,c]==1]>=0)


@variable(m, rλ[c in consumers,p in producers,f in traded_fuels, n in nodes,nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],Bin)


@constraint(m, FuelPurchasingConstraint1[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                0 <= qFuelPurchased[c,p,f,n,nn,y,] - qFuelSold[p,c,f,nn,n,y]  
                )

@constraint(m, FuelPurchasingConstraint2[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                qFuelPurchased[c,p,f,n,nn,y,] - qFuelSold[p,c,f,nn,n,y] <= rλ[c,p,f,n,nn,y] * BIG
                )

@constraint(m, FuelPurchasingConstraint3[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                λ[c,p,f,n,nn,y,] <= (1 - rλ[c,p,f,n,nn,y]) * BIG
                )

#### Physical Hydrogen Market Constraint 
@constraint(m, PhysicalFuelPurchasingConstraint2[c in consumers, p in producers, f in traded_fuels,n in nodes, nn in nodes, y in years;
                haskey(qFuelPurchased,(c,p,f,n,nn,y)) && haskey(qFuelSold, (p,c,f,nn,n,y))],
                qFuelPurchased[c,p,f,n,nn,y,] - qFuelSold[p,c,f,nn,n,y] ==0
                )

### 
@constraint(m, FuelMarketConstraint[f in traded_fuels,n in nodes,y in years], 
            sum(qProcess[p,ρ,f,n,y] * sO[ρ,f] for p in ["Port"], ρ in processes if haskey(sO,(ρ,f)) && haskey(iNm,(n,p)) && pIm[p,ρ]==1)
        +   sum(qFuelImports[c,s,f,n,nn,m,y] for c in consumers_ports,s in  producers_ports, nn in nodes,m in modes if haskey(qFuelImports, (c,s,f,n,nn,m,y)))     
        +   sum(qFuelSold[s,c,f,n,nn,y] for s in  producers, c in consumers, nn in nodes if haskey(qFuelSold, (s,c,f,n,nn,y))) 
        == 
            sum(qFuelExports[p,c,f,n,nn,m,y]
            for p in  producers_ports, c in consumers_ports, nn in nodes, m in modes if nn!=n && haskey(qFuelExports, (p,c,f,n,nn,m,y)))   
        + sum(qProcess[p,ρ,ff,n,y]  *  sI[ρ,f,ff,y] 
        for p in ["Port"],ρ in processes, ff in traded_fuels if haskey(sI, (ρ,f,ff,y) ) && pIm[p,ρ]==1 && haskey(iNm,(n,p)))
        +   sum(qFuelPurchased[c,p,f,n,nn,y] for c in consumers, p in producers, nn in nodes if haskey(qFuelPurchased, (c,p,f,n,nn,y))) 
)

################################### Objective Function
cH2 = 1000      # EUR/t H2 ~ 1 EUR/kg

@objective(m, Max, sum((λ[c,p,f,n,nn,y]-cH2) * qFuelSold[p,c,f,nn,n,y] for c in consumers,p in producers, n in nodes, nn in nodes, y in years, f in traded_fuels if haskey(qFuelSold, (p,c,f,nn,n,y))))

set_optimizer(m,Gurobi.Optimizer)
set_optimizer_attribute(m, "NumericFocus", 3) 
set_optimizer_attribute(m, "IntFeasTol", 1e-9)
set_optimizer_attribute(m, "InfUnbdInfo", 1)

optimize!(m)





CO2Price

value.(λ)/(1e3)

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