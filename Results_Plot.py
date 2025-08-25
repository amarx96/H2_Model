# %%
import pandas as pd
import matplotlib.pyplot as plt
import os
import pandas as pd
import numpy as np
# %%
# Define the categories
downstream_industries = ['Hvc', 'Steel', 'Hvcs', 'Fertilizer', "Shipping", "Aviation"]  # Add your downstream industries
upstream_industries = ['H2 Producer',"NH3 Producer", "MeOH Producer" ,'Port']  # Add your upstream industries


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
results_folder = r"C:\Users\alex-\Desktop\09_11_Rechenkern\_code\data"
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder,"_industryLocationMap.csv")
locations = pd.read_csv(file_path)
locations.head()
# %%
'''
Fuels Sold
'''
# Load the selected CSV file into a DataFrame
file_path = os.path.join(results_folder,"qFuelSold.csv")
df = pd.read_csv(file_path)

df
# %% 2024
'''
Fuels Sold 2030
'''
