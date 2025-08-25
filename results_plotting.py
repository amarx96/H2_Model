# %%
import pandas as pd
import matplotlib.pyplot as plt
import os
import pandas as pd
import numpy as np
# %%  # Prepare Plotting
# Define the categories
downstream_industries = ['Hvc', 'Steel', 'Hvcs', 'Fertilizer', "Shipping", "Aviation"]  # Add your downstream industries
upstream_industries = ['H2 Producer',"NH3 Producer", "MeOH Producer" ,'Port']  # Add your upstream industries

# %% 

 # Process color mapping
# Define the extended process color mapping
process_colors = {
    # Steel Production
    "Bof": "#3B2F2F",        # Brown-black for Basic Oxygen Furnace
    "Dri": "#FFD700",        # Gold for Direct Reduced Iron

    # Hydrogen and Hydrogen-derived processes
    "Smr": "#FF8C00",        # Dark Orange for Steam Methane Reforming
    "Hb": "#8A2BE2",         # Blue Violet for Haber-Bosch Ammonia production
    "H2 ICE": "#1E90FF",     # Dodger Blue for Hydrogen ICE
    "NH3 ICE": "#4682B4",    # Steel Blue for Ammonia ICE
    "MeOH ICE": "#FFD39B",   # Burly Wood for Methanol ICE
    "MeOHSyn": "#FFA500",    # Orange for Methanol Synthesis

    # Naphtha and Gas-related processes
    "Nto/Nta": "#8B0000",    # Dark Red for Naphtha to Olefins
    "LNG ICE": "#2F4F4F",    # Dark Slate Gray for LNG ICE
    "Conventional ICE": "#556B2F",  # Dark Olive Green for Conventional ICE

    # Other processes
    "Mto/Mta": "#FF6347",    # Tomato for Methanol to Aromatics
    "Rwgs": "#6B8E23",       # Olive Drab for Reverse Water Gas Shift (biomass-related)
    "Fertilizer Synthesis": "#696969",  # Dark Gray for Nitrification
    "Asu": "#9370DB",        # Medium Purple for Air Separation of CO2
    "Btm": "#228B22",        # Forest Green for Biomass-to-Methanol
    "Dac": "#008080",        # Teal for Direct Air Capture
    "Esc": "#00BFFF",        # Deep Sky Blue

    # Renewable Energy Sources
    "Onwind": "#00CED1",     # Dark Turquoise for Onshore Wind
    "Pv": "#FFD700",         # Gold for Solar PV
    "Offwind": "#1E90FF",    # Dodger Blue for Offshore Wind
    "El": "#6495ED",         # Medium Slate Blue for Electricity
    "SmrCCTS": "#20B2AA",    # Light Sea Green for SMR with Carbon Capture
    "AmCr": "#8A2BE2",       # Blue Violet for Ammonia Cracking
    "H2Liq": "#4682B4",      # Steel Blue for Hydrogen Liquefaction
    "H2Eva": "#00BFFF"       # Deep Sky Blue for Hydrogen Evaporation
}

input_colors = {
    'Onwind': '#32CD32',      # Green for Onshore Wind (renewable)
    'Offwind': '#006400',     # Dark Green for Offshore Wind (renewable)
    'Solar': '#FFD700',       # Gold for Solar (renewable)
    'H2': '#96ffff',          # Hydrogen (Light Cyan)
    'NH3': '#90EE90',         # Ammonia (Light Green)
    'Gas': '#8B4513',         # Gas (SaddleBrown)
    'Coal': '#4B4B4B',        # Blackish Gray for Coal
    'Electricity': '#FFD700', # Electricity (Gold)
    'MGO': '#e54213',         # Marine Gas Oil (Red)
    'Biodiesel': '#228B22',   # Biodiesel (Forest Green)
    'LNG': '#2F4F4F',         # Liquefied Natural Gas (Dark Slate Gray)
    'MeOH': '#FFA07A',        # Methanol (Light Salmon)
    'Naphtha': '#FF8C00',     # Naphtha (Dark Orange)
    'CO2': '#D2691E',         # Chocolate Brown for Carbon Dioxide
    'N': '#A52A2A',           # Red-Brown for Nitrogen
    'Biomass': '#006400',     # Biomass (Dark Green)
    'Power': '#2A2A2A',       # Generic Power Input (Dark Gray)
    'BMeOH': '#90EE90',       # Biomass-derived Methanol (Light Green)
    'LCH2': '#00CED1',        # Low-Carbon Hydrogen (Dark Turquoise)
    'HCH2': '#191970',        # High-Carbon Hydrogen (Midnight Blue)
    'LCMeOH': '#FF4500',      # Low-Carbon Methanol (Orange Red)
    'NH3': '#8A2BE2',         # Ammonia (Purple)
    'LH2': '#00008B'          # Liquefied Hydrogen (Deep Blue)
}
# %%
# Import Path to the results folder
results_folder = r"C:\Users\alex-\Desktop\09_11_Rechenkern\_code\results"


# Export Path
graphics_folder = r"C:\Users\alex-\Desktop\09_11_Rechenkern\_code\graphics"
if not os.path.exists(graphics_folder):
    os.makedirs(graphics_folder)


# List all .csv files in the results folder
csv_files = [file for file in os.listdir(results_folder) if file.endswith(".csv")]
csv_files
# %%
'''
Fuels Sold
'''
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder,"qFuelSold.csv")
df = pd.read_csv(file_path)
df['Fuel_Color'] = df['Fuel'].map(input_colors).fillna('#808080')

df
# %%
# Pivot the data to create a DataFrame where each column is a different fuel
pivot_df = df.pivot_table(index="Year", columns="Fuel", values="Value", aggfunc="sum", fill_value=0)

# Create a mapping for each Fuel to its corresponding color
color_dict = df[['Fuel', 'Fuel_Color']].drop_duplicates().set_index('Fuel')['Fuel_Color'].to_dict()

# Plot
fig, ax = plt.subplots(figsize=(8, 6))

# Initialize bottom values for stacking
bottom_values = np.zeros(len(pivot_df))

# Iterate over the fuels and plot them as stacked bars
for fuel in pivot_df.columns:
    # Get the color for the fuel or default to grey
    fuel_color = color_dict.get(fuel, '#808080')
    ax.bar(
        pivot_df.index, pivot_df[fuel],
        color=fuel_color,
        label=fuel,
        bottom=bottom_values
    )
    # Update the bottom values
    bottom_values += pivot_df[fuel].values

# Add labels and title
ax.set_xlabel("Year", fontsize=12)
ax.set_ylabel(r"$\text{tons} \, \text{yr}^{-1}$", fontsize=12)
ax.set_title("Fuel Demand by Downstream Industries", fontsize=14)

# Add the legend
ax.legend(title="Fuel", fontsize=10)

# Optional: Save the plot
graphics_folder = "./graphics"  # Change to your desired folder path
os.makedirs(graphics_folder, exist_ok=True)
plot_path = os.path.join(graphics_folder, "fuel_demand.png")
plt.savefig(plot_path, dpi=300)

# Show the plot
plt.tight_layout()
plt.show()
# %%
'''
Process Fuel Demand
'''
#### Process Fuel Demand
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder,"qProcessFuelDemand.csv")
df = pd.read_csv(file_path)

df['Input'] = df['Input'].replace('na', 'Power')

# Group by the specified columns and sum the 'Value' column
df = df.groupby(['Industry', 'Input', 'Location', 'Year'], as_index=False)['Value'].sum()

# Ensure any undefined 'Input' gets a default color (grey)
df['Input_Color'] = df['Input'].map(input_colors).fillna('#808080')

                                                       

# Subset for downstream industries
downstream_df = df[df['Industry'].isin(downstream_industries)]


# %%
# Downstream Graph: Fuel Demand
fig, ax = plt.subplots(figsize=(8, 6))

# Pivot the data to create a DataFrame where each column is a different process
downstream_pivot = downstream_df.pivot_table(index="Year", columns="Input", values="Value", aggfunc="sum", fill_value=0)

# Create a mapping for each Input to its corresponding color from the 'Input_Color' column
color_dict = downstream_df.set_index('Input')[['Input_Color']].to_dict()['Input_Color']

# Plot the stacked bar chart
bottom_values = [0] * len(downstream_pivot)  # Initialize bottom values for stacking

# Iterate over the processes and plot them as stacked bars
for process in downstream_pivot.columns:
    # Use the color from the color dictionary, defaulting to grey if not found
    process_color = color_dict.get(process, '#808080')  # Default to grey if no color is defined
    ax.bar(downstream_pivot.index, downstream_pivot[process], 
           color=process_color,  # Use the process-specific color
           label=process, 
           bottom=bottom_values)
    
    # Update the bottom values for the next stack
    bottom_values += downstream_pivot[process].values

# Add labels and title
ax.set_xlabel("Year", fontsize=12)
ax.set_ylabel(r"$\text{tons} y^{-1}$", fontsize=12)
ax.set_title("Fuel demand by downstream industries", fontsize=14)

# Add the legend with process labels
ax.legend(title="Fuel")

# Show the plot
# Save the plot
plot_path = os.path.join(graphics_folder, "fuel_demand.png")
plt.savefig(plot_path, dpi=300)

plt.show()

# %%
'''
Process
'''
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder, "qProcess.csv")
df = pd.read_csv(file_path)
df

# Subset for downstream industries
downstream_df = df[df['Industry'].isin(downstream_industries)]
upstream_df = df[df['Industry'].isin(upstream_industries)]

downstream_df = downstream_df.groupby(['Process', 'Year'], as_index=False)['Value'].sum()
upstream_df = upstream_df.groupby(['Process', 'Year'], as_index=False)['Value'].sum()

downstream_pivot = downstream_df.pivot_table(index="Year", columns="Process", values="Value", aggfunc="sum", fill_value=0)
upstream_pivot = upstream_df.pivot_table(index="Year", columns="Process", values="Value", aggfunc="sum", fill_value=0)

# %% ### Upstream Processes
# Plot the stacked bar chart
fig, ax = plt.subplots(figsize=(8, 6))

# Initialize bottom values for stacking
bottom_values = [0] * len(upstream_pivot)

# Iterate over each process and plot as stacked bars
for process in upstream_pivot.columns:
    # Get the corresponding color for each process
    process_color = process_colors.get(process, '#808080')  # Default to grey if not found
    ax.bar(upstream_pivot.index, upstream_pivot[process], 
           color=process_color, 
           label=process, 
           bottom=bottom_values)
    
    # Update the bottom values for the next stack
    bottom_values += upstream_pivot[process].values

# Add labels and title
ax.set_xlabel("Year", fontsize=12)
ax.set_ylabel(r"$\text{tons} \, y^{-1}$", fontsize=12)
ax.set_title("Production by processes by upstream industries", fontsize=14)

# Add the legend with process labels
ax.legend(title="Processes", bbox_to_anchor=(1.05, 1), loc='upper left')

# Adjust layout and show plot
plt.tight_layout()

plot_path = os.path.join(graphics_folder, "upstream_processes.png")
plt.savefig(plot_path, dpi=300)


plt.show()
# %% Donwnstream
# Plot the stacked bar chart
fig, ax = plt.subplots(figsize=(8, 6))

# Initialize bottom values for stacking
bottom_values = [0] * len(downstream_pivot)

# Iterate over each process and plot as stacked bars
for process in downstream_pivot.columns:
    # Get the corresponding color for each process
    process_color = process_colors.get(process, '#808080')  # Default to grey if not found
    ax.bar(downstream_pivot.index, downstream_pivot[process], 
           color=process_color, 
           label=process, 
           bottom=bottom_values)
    
    # Update the bottom values for the next stack
    bottom_values += downstream_pivot[process].values

# Add labels and title
ax.set_xlabel("Year", fontsize=12)
ax.set_ylabel(r"$\text{tons} \, y^{-1}$", fontsize=12)
ax.set_title("Production by processes by upstream industries", fontsize=14)

# Add the legend with process labels
ax.legend(title="Processes", bbox_to_anchor=(1.05, 1), loc='upper left')

# Adjust layout and show plot
plt.tight_layout()

plot_path = os.path.join(graphics_folder, "downstream_processes.png")
plt.savefig(plot_path, dpi=300)


plt.show()
# %%
'''
Capacity Accumulation
'''
# %%
#### Accumulated Capacity
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder, "qAccCapacity.csv")
df = pd.read_csv(file_path)


# Subset for downstream industries
downstream_df = df[df['Industry'].isin(downstream_industries)]
upstream_df = df[df['Industry'].isin(upstream_industries)]

downstream_df = downstream_df.groupby(['Process', 'Year'], as_index=False)['Value'].sum()
upstream_df = upstream_df.groupby(['Process', 'Year'], as_index=False)['Value'].sum()

downstream_pivot = downstream_df.pivot_table(index="Year", columns="Process", values="Value", aggfunc="sum", fill_value=0)
upstream_pivot = upstream_df.pivot_table(index="Year", columns="Process", values="Value", aggfunc="sum", fill_value=0)
# %%
# Upstream Graph: Accumulated Capacity
fig, ax = plt.subplots(figsize=(8, 6))

# Initialize bottom values for stacking
bottom_values = [0] * len(upstream_pivot)

# Iterate over each process and plot as stacked bars
for process in upstream_pivot.columns:
    # Get the corresponding color for each process
    process_color = process_colors.get(process, '#808080')  # Default to grey if not found
    ax.bar(upstream_pivot.index, upstream_pivot[process], 
           color=process_color, 
           label=process, 
           bottom=bottom_values)
    
    # Update the bottom values for the next stack
    bottom_values += upstream_pivot[process].values

# Add labels and title
ax.set_xlabel("Year", fontsize=12)
ax.set_ylabel(r"$\text{tons} \, y^{-1}$", fontsize=12)
ax.set_title("Production capacity by processes by upstream industries", fontsize=14)

# Add the legend with process labels
ax.legend(title="Processes", bbox_to_anchor=(1.05, 1), loc='upper left')

# Adjust layout and show plot
plt.tight_layout()

plot_path = os.path.join(graphics_folder, "upstream_processes_capacity.png")
plt.savefig(plot_path, dpi=300)


plt.show()
# %%
# Downstream Graph: Accumulated Capacity
fig, ax = plt.subplots(figsize=(8, 6))

# Initialize bottom values for stacking
bottom_values = [0] * len(downstream_pivot)

# Iterate over each process and plot as stacked bars
for process in downstream_pivot.columns:
    # Get the corresponding color for each process
    process_color = process_colors.get(process, '#808080')  # Default to grey if not found
    ax.bar(downstream_pivot.index, downstream_pivot[process], 
           color=process_color, 
           label=process, 
           bottom=bottom_values)
    
    # Update the bottom values for the next stack
    bottom_values += downstream_pivot[process].values

# Add labels and title
ax.set_xlabel("Year", fontsize=12)
ax.set_ylabel(r"$\text{tons} \, y^{-1}$", fontsize=12)
ax.set_title("Production capacity by processes by downstream industries", fontsize=14)

# Add the legend with process labels
ax.legend(title="Processes", bbox_to_anchor=(1.05, 1), loc='upper left')

# Adjust layout and show plot
plt.tight_layout()

plot_path = os.path.join(graphics_folder, "downstream_processes_capacity.png")
plt.savefig(plot_path, dpi=300)


plt.show()
# %%
'''
        Export Quantities
'''
# %%
df = pd.read_csv(file_path)

df
# %%
#### Export Accumulation
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder, "qFuelExports.csv")
df = pd.read_csv(file_path)

df = (
    df.groupby(["Fuel", "Mode", "Year"], as_index=False)
    .agg({"Value": "sum"})
    .rename(columns={"Industry": "Transport Node"})
)

df["Fuel_Mode"] = df["Fuel"] + "_" + df["Mode"]
df
# %%
# Create a pivot table for easier plotting
pivot_df = df.pivot_table(index='Year', columns='Fuel_Mode', values='Value', aggfunc='sum')

# Plot the data as a bar graph
pivot_df.plot(kind='bar', stacked=True, figsize=(12, 7))

# Customize the plot
plt.title('Fuel Mode Value Over Years')
plt.xlabel('Year')
plt.ylabel('Value')
plt.xticks(rotation=0)  # Keep x-axis labels horizontal
plt.legend(title='Fuel Mode', bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()  # Adjust layout to fit everything
plt.grid(True)

# Show the plot
plt.show()
# %%
'''
        Export Quantities
'''
#### Export Accumulation
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder, "qFuelExports.csv")
df = pd.read_csv(file_path)

df = (
    df.groupby(["Fuel", "Mode", "Year"], as_index=False)
    .agg({"Value": "sum"})
    .rename(columns={"Industry": "Transport Node"})
)

df["Fuel_Mode"] = df["Fuel"] + "_" + df["Mode"]
df
