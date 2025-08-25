Set-Location -Path 'C:\Users\alex-\Desktop\H2_Modell\_code'

$readme = @"
# H2_Modell

A mixed Julia/Python workspace for hydrogen value-chain modeling, market setup, optimization (JuMP + Gurobi/HiGHS), and visualization.

## Contents
- Julia model sources: core optimization, market/data setup, exports
- Python utilities: result plotting, EU ETS visualizations, geocoding utilities
- Data: CSV/XLSX inputs under `data/`
- Outputs: CSV results under `results/` and figures under `graphics/`

## Prerequisites
- Julia 1.9+ with packages used across files (common: JuMP, Gurobi, HiGHS, CSV, DataFrames, DataStructures, Revise, Plots, StatsPlots)
- Python 3.9+ with packages (common: pandas, numpy, matplotlib, scipy, geopy, openpyxl, networkx)
- Optional: Gurobi installed and licensed for Julia. Otherwise use HiGHS where available.
- Optional: Git LFS (recommended for large CSV/XLSX and figures)

## Quick start
1) Clone the repo and open the `_code/` folder in VS Code.
2) Julia environment
   - Open a Julia REPL in `_code/` and run:
     - using Pkg; Pkg.activate("."); Pkg.add(["JuMP","Gurobi","HiGHS","CSV","DataFrames","DataStructures","Revise","Plots","StatsPlots"])  # one-time
   - Adjust solver calls: use `Gurobi.Optimizer` if licensed, or switch to `HiGHS.Optimizer`.
3) Python environment
   - Create/activate a virtual env and install the basics: pandas, numpy, matplotlib, scipy, geopy, openpyxl, networkx.

## Data and results
- Inputs live in `data/`. Large files are tracked with Git LFS (see `.gitattributes`).
- Model results (CSV) are in `results/`. Plots go to `graphics/`.

## Notes
- Several prototype files contain placeholders or incomplete blocks; stabilize them incrementally.
- Paths referencing local Windows folders can be parameterized later to improve portability.

## License
MIT License (see LICENSE)
"@
Set-Content -Path 'README.md' -Value $readme -Encoding UTF8

$gitignore = @"
# OS / Editor
.DS_Store
Thumbs.db
.vscode/
.history/
.idea/
*.log

# Python
__pycache__/
*.py[cod]
*.pyo
.ipynb_checkpoints/
.venv/
venv/
.env

# Julia
.julia/
*.jl.cov
*.jl.mem
Manifest.toml

# Notebooks
*.ipynb~

# Build/Cache
dist/
build/
.cache/

# Optional: keep results & data tracked via LFS (see .gitattributes)
# results/
# graphics/
# data/
"@
Set-Content -Path '.gitignore' -Value $gitignore -Encoding UTF8

$license = @"
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@
Set-Content -Path 'LICENSE' -Value $license -Encoding UTF8

$gitattributes = @"
# Use Git LFS for large/binary artifacts in data/results/graphics
/data/** filter=lfs diff=lfs merge=lfs -text
/results/** filter=lfs diff=lfs merge=lfs -text
/graphics/** filter=lfs diff=lfs merge=lfs -text

# Common binaries
*.xlsx filter=lfs diff=lfs merge=lfs -text
*.xls  filter=lfs diff=lfs merge=lfs -text
*.png  filter=lfs diff=lfs merge=lfs -text
*.jpg  filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
*.svg  filter=lfs diff=lfs merge=lfs -text
"@
Set-Content -Path '.gitattributes' -Value $gitattributes -Encoding UTF8

# Optionally enable Git LFS if available
if (Get-Command git-lfs -ErrorAction SilentlyContinue) { git lfs install }

# Commit
git add .
$env:GIT_COMMITTER_DATE = (Get-Date).ToString('o')
$env:GIT_AUTHOR_DATE = (Get-Date).ToString('o')
git commit -m "chore: initial commit with repo scaffolding and sources"

# Attempt to create/push GitHub repo via gh CLI
if (Get-Command gh -ErrorAction SilentlyContinue) {
  gh repo create H2_Modell --private --source=. --remote=origin --push
  git remote -v
} else {
  Write-Host "GitHub CLI (gh) not found. Repo is initialized locally."
  git remote -v
}

git status -b --porcelain