# %%
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

#%%
# Create the 'graphics' folder if it doesn't exist
graphics_folder = r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\graphics'
if not os.path.exists(graphics_folder):
    os.makedirs(graphics_folder)

# %%

# Define the file path
file_path = r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\data\_e_benchmark.xlsx'

# Import the data from the Excel file
df = pd.read_excel(file_path,sheet_name="_e_benchmark")
df['Year'] = df['Year'].round().astype(int)
df['Year'] = df['Year'].round().astype(int).astype(str)

print(df.head())


# %%
# Set figure dimensions and font sizes for consistency
fig_size = (10, 6)
label_fontsize = 18
legend_fontsize = 16
tick_labelsize = 16

# Plot 1: Emission Benchmarking Plot
plt.figure(figsize=fig_size)


for industry in df['Industry'].unique():
    industry_data = df[df['Industry'] == industry]
    plt.plot(industry_data['Year'], industry_data['Value'], label=industry, marker='o')

plt.xlabel('', fontsize=label_fontsize)
plt.ylabel('t CO$_2$ /t process output', fontsize=label_fontsize)
plt.legend(title='Industry', fontsize=legend_fontsize)
plt.tick_params(axis='both', which='major', labelsize=tick_labelsize)
plt.grid(True)
plt.tight_layout()

plot_file_path = os.path.join(graphics_folder, 'emission_benchmarking_plot.jpg')
plt.savefig(plot_file_path, dpi=300, bbox_inches='tight')
plt.show()

# %%
# Define the file path
file_path = r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\data\CO2Price.xlsx'

data = pd.read_excel(file_path,sheet_name="output")
data['Year'] = data['Year'].round().astype(int)
data['Year'] = data['Year'].round().astype(int).astype(str)
# %%
# Plot 2: CO2 Price Plot
plt.figure(figsize=fig_size)

plt.plot(data['Year'], data['CO2Price'], marker='o', linestyle='-', color='b')
plt.xlabel('', fontsize=label_fontsize)
plt.ylabel(r'p^{CO_2}$ in EUR /tCO$_2$', fontsize=label_fontsize)
plt.tick_params(axis='both', which='major', labelsize=tick_labelsize)
plt.legend(title='Industry', fontsize=legend_fontsize)  # Ensure legend consistency
plt.grid(True)
plt.tight_layout()

plot_file_path = os.path.join(graphics_folder, 'CO2_Price.jpg')
plt.savefig(plot_file_path, dpi=300, bbox_inches='tight')
plt.show()

s# %%

# %%
# Load data from CSV file
file_path = r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\data\_rfnbo_quotas.xlsx'  # Replace with the correct filename if different
data = pd.read_excel(file_path,sheet_name="_rfnbo")

data['Year'] = data['Year'].round().astype(int)
data['Year'] = data['Year'].round().astype(int).astype(str)

blue_palette = [
    '#1f77b4',  # Base Blue
    '#4c84c6',  # Light Blue 1
    '#7fa8d7',  # Light Blue 2
    '#a2c8e9',  # Light Blue 3
    '#c5e1f3'   # Very Light Blue
]

data.head()
# %%
fig_size = (10, 6)
label_fontsize = 14
legend_fontsize = 16
tick_labelsize = 14
# Plot data
plt.figure(figsize=fig_size)

# Loop through each sector to plot with custom colors
for i, sector in enumerate(data['Sector'].unique()):
    sector_data = data[data['Sector'] == sector]
    color = blue_palette[i % len(blue_palette)]  # Assign color from the palette
    plt.plot(sector_data['Year'], sector_data['Value'], marker='o', label=sector, color=color)

# Customize plot
plt.title('')
plt.xlabel('Year', fontsize=label_fontsize)
plt.ylabel(r'RFNBO Target  (% of total fuel demand)', fontsize=label_fontsize)
plt.tick_params(axis='both', which='major', labelsize=tick_labelsize)
plt.legend(title='Sector', fontsize=legend_fontsize)  # Ensure legend consistency
plt.grid(True)

# Save and display plot
plt.savefig(r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\graphics\rfnbo_targets_plot.png', dpi=300)
plt.show()

# %%    Grouped Bar plot for RFNBO targets   
# Load data from CSV file
file_path = r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\data\_rfnboFuelMap.xlsx'  # Replace with the correct filename if different
data = pd.read_excel(file_path,sheet_name="Tabelle1")
df = data[data["Value"]!=0]
df = df[~df["Input"].isin(["LCMeOH","LCNH3", "NH3", "MeOH", "N", "CO2"])]
df.loc[(df['Input'] == 'Naphtha') & (df['Process'] == 'Esc'), 'Input'] = 'Naphtha - ESC'
df.loc[(df['Input'] == 'H2') & (df['Process'] == 'H2 ICE'), 'Input'] = 'H2, NH3, MeOH - Transport Sector'
df.loc[(df['Input'] == 'H2'),"Input"] = "H2, NH3, MeOH"
df.loc[(df['Input'] == 'LCH2'),"Input"] = "LCH2, LCNH3, LCMeOH"
df = df.drop(columns=["Process"]).drop_duplicates()
df = df.drop_duplicates(subset=["Year", "Input"])
df.head()

blue_palette = [
    '#1f77b4',  # Base Blue
    '#4c84c6',  # Light Blue 1
    '#7fa8d7',  # Light Blue 2
    '#a2c8e9',  # Light Blue 3
    '#c5e1f3'   # Very Light Blue
]

# %%    Grouped Bar plot for RFNBO targets        

# Sort the data by 'Input' (fuel type) and 'Year'
df_sorted = df.sort_values(by=['Input', 'Year'])

# Pivot data for grouped bar plotting
pivot_df = df_sorted.pivot_table(index='Year', columns='Input', values='Value')

# Bar width and positions
bar_width = 0.15
x = np.arange(len(pivot_df.index))  # Year indices

# Plotting
fig, ax = plt.subplots(figsize=(12, 6))

# Create bars for each fuel type (grouped by year)
for i, col in enumerate(pivot_df.columns):
    ax.bar(x + i * bar_width, pivot_df[col], width=bar_width, label=f"{col}",color=blue_palette[i % len(blue_palette)])

# Customizing the plot
ax.set_xticks(x + bar_width * (len(pivot_df.columns) - 1) / 2)  # Adjust x-axis ticks for grouped bars
ax.set_xticklabels(pivot_df.index)  # Set Year labels
ax.set_xlabel("Year")
ax.set_ylabel("Weight")
ax.set_title("")
ax.legend(title="Fuel Type", bbox_to_anchor=(1.05, 1), loc='upper left')
ax.grid(axis="y", linestyle="--", alpha=0.7)

# Show plot
plt.savefig(r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\graphics\RFNBO_Weight.png', dpi=300)
plt.tight_layout()
plt.show()
# %%
# Drop rows where the 'Value' column is 0
data = data[data["Value"] != 0]

data['Year'] = data['Year'].round().astype(int)
data['Year'] = data['Year'].round().astype(int).astype(str)

data = data[data["Input"].isin(["Electricity", "LCH2"])][["Process", "Input","Value", "Year"]]
data = data[data["Process"].isin(["Dri", "SmrCCTS"])][["Process", "Input","Value", "Year"]]
data = data.drop_duplicates()
data.loc[data["Input"] == "Electricity", 'Process'] = data.loc[data["Input"] == "Electricity", 'Process'].replace("Dri", "from the grid")
data.loc[data["Input"] == "LCH2", 'Process'] = data.loc[data["Input"] == "LCH2", 'Process'].replace("Dri", "from SMR with CC")
data['Process_Input'] = data['Input'] + " " + data['Process']
# %%

# Plot data
fig_size = (10, 6)
label_fontsize = 14
legend_fontsize = 16
tick_labelsize = 14

plt.figure(figsize=fig_size)
for sector in data['Process_Input'].unique():
    sector_data = data[data['Process_Input'] == sector]
    plt.plot(sector_data['Year'], sector_data['Value'], marker='o', label=sector)
    
    
plt.tick_params(axis='both', which='major', labelsize=tick_labelsize)


    # Customize plot
plt.title('')
plt.xlabel('', fontsize=label_fontsize)
plt.ylabel(r'RFNBO weight $\omega_{f,\rho}$', fontsize=label_fontsize)
plt.tick_params(axis='both', which='major', labelsize=tick_labelsize)
plt.legend(title='Sector', fontsize=legend_fontsize)  # Ensure legend consistency
plt.grid(True)


# Save and display plot
plt.savefig(r'C:\Users\alex-\Desktop\09_11_Rechenkern\_code\graphics\RFNBO_Weight.png', dpi=300)
plt.show()

# %%
data

# %%
