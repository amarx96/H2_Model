Set-Location -Path 'C:\Users\alex-\Desktop\H2_Modell\_code'

$section = @"

## Example results (illustrative)
Below are example figures generated from model outputs (see `results/`) and plotting utilities. Place the corresponding images under `graphics/` for the links to render on GitHub.

- Domestic H2 deliveries (Sankey): producer supplies HVC, Steel, and Fertilizer demand centers.
  
  <img src="graphics/example_sankey_domestic.png" alt="Domestic H2 Sankey" width="720" />

- Export chain (Sankey): multi-node path Producer → Port → Consumer, annotated with kt volumes per year.
  
  <img src="graphics/example_sankey_exports.png" alt="Export chain Sankey" width="720" />

- Shipping transition: conventional ICE declines while LNG/NH3-based options scale over time.
  
  <img src="graphics/example_shipping_transition.png" alt="Shipping process transition" width="720" />

- Steel transition: Basic Oxygen Furnace (BOF) phases out; DRI ramps up in later years.
  
  <img src="graphics/example_steel_transition.png" alt="Steel process transition" width="720" />

- Aviation demand stack (illustrative): DAC-based synthetic fuels and FT ramp towards 2050.
  
  <img src="graphics/example_aviation_stack.png" alt="Aviation demand stack" width="720" />

- CO2 price trajectory and ETS benchmarks: exogenous carbon price path and emissions intensity benchmarks converging to near-zero by 2050.
  
  <img src="graphics/example_co2_price.png" alt="CO2 price path" width="720" />
  
  <img src="graphics/example_ets_benchmarks.png" alt="ETS benchmark convergence" width="720" />

Notes
- Figures are illustrative; values depend on scenario inputs (price paths, technology costs, quotas) located in `data/`.
- Use the plotting scripts (`results_plotting.py`, `Results_Plot.py`, `EU_ETS_viz.py`) to regenerate visuals from fresh runs.
"@

Add-Content -Path 'README.md' -Value $section -Encoding UTF8

git add README.md
if ((git diff --cached --name-only) -ne $null) { git commit -m "docs: add example results gallery with figure slots" } else { Write-Host "No README changes to commit." }

git push -u origin main
## Example results (illustrative)
These figures are generated from sample scenarios. Values are illustrative and depend on inputs under data/.

- Model scope and architecture

  <img src="graphics/model_intro.png" alt="Model overview" width="800" />

- Example trade network map

  <img src="graphics/h2_viz_map.png" alt="H2 trade network map" width="800" />

- RFNBO-constrained vs. unconstrained trade flows (2050)

  <img src="graphics/sankey_rfnbo_cap_2050.png" alt="Sankey with RFNBO capacity constraint" width="800" />
  <img src="graphics/sankey_rfnbo_wo_cap_2050.png" alt="Sankey without RFNBO capacity constraint" width="800" />

- Sector process outputs (Stackelberg examples)

  <img src="graphics/steel_stackelberg.png" alt="Steel process outputs" width="800" />
  <img src="graphics/fertilizer_stackelberg.png" alt="Fertilizer process outputs" width="800" />

- Aviation and Shipping illustrative transitions

  <img src="graphics/aviation_process_rfnbo.png" alt="Aviation process mix" width="800" />
  <img src="graphics/shipping_process_rfnbo.png" alt="Shipping process mix" width="800" />

- CO2 price path and ETS benchmark convergence

  <img src="graphics/co2_price.jpg" alt="CO2 price path" width="600" />
  <img src="graphics/ets_benchmarks.jpg" alt="ETS benchmark convergence" width="600" />

- Residual capacities snapshot

  <img src="graphics/residual_capacities.png" alt="Residual capacities" width="800" />

