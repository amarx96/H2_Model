# %%

import networkx as nx
import matplotlib.pyplot as plt
import pandas as pd
#%%

os.chdir(r'C:\Users\alex-\Desktop\H2VCS Rechenkern\RechenkernUpdate6\_code\data')

# If the data is stored in a CSV file, you can read it directly:
df = pd.read_excel('processIndustryMap.xlsx', index_col=0)
df = df.fillna(0)
ds = df[["Steel", "Fertilizer", "Hvc", "Shipping","Aviation"]]
ds = ds.loc[~(df[["Steel", "Fertilizer", "Hvc", "Shipping","Aviation"]].sum(axis=1) == 0)]  # 
ds
# %%
# Define the positions dictionary to control the layout
pos = {}

# Set horizontal gap for process nodes
process_gap = 1.2
industry_gap = 3  # Gap between different industries vertically

# Counter to shift each industry's processes vertically
y_offset = 0

# Iterate through each industry and add the corresponding processes to the graph
for industry in industries:
    # Add the industry node
    G.add_node(industry, type='industry')

    # Get the processes that the current industry uses (where the value is 1)
    used_processes = df.index[df[industry] == 1].tolist()

    # Add process nodes and edges for each used process
    for i, process in enumerate(used_processes):
        # Create a unique process name for the industry
        unique_process = f"{process}_{industry}"

        # Add the unique process node
        G.add_node(unique_process, type='process')

        # Add an edge from the industry to this unique process node
        G.add_edge(industry, unique_process)  # Connect the industry to the process

        # Set the position for the process node (adjusted vertically for each industry)
        pos[unique_process] = (0, i * process_gap + y_offset)  # Processes are vertically stacked

    # Set the position for the industry node (above its processes)
    pos[industry] = (0.5, len(used_processes) * process_gap / 2 + y_offset)

    # Update the y_offset to avoid overlap between industries
    y_offset += industry_gap

# Ensure all nodes are in the position dictionary
for node in G.nodes:
    if node not in pos:
        pos[node] = (0, 0)  # Assign a default position if missing

# Plotting the graph
plt.figure(figsize=(12, 10))  # Adjust the size for better visibility

# Draw the graph with the specified positions
nx.draw(G, pos, with_labels=True, node_size=500, node_color='skyblue', font_size=10, font_weight='bold', edge_color='gray')

# Set title
plt.title('Industry-Process Graph with Unique Process Nodes')

# Display the plot
plt.show()
# %%

G.add_nodes_from(industries)

# Add edges based on the matrix (process to industry)
for i, process in enumerate(processes):
    for j, industry in enumerate(industries):
        if matrix[i][j] == 1:
            G.add_edge(process, industry, label=f"{process} -> {industry}")
            
            # %%
            
# Draw the graph
plt.figure(figsize=(12, 12))
pos = nx.spring_layout(G, k=0.2, seed=42)  # Layout for better separation
nx.draw(G, pos, with_labels=True, node_size=5000, node_color='skyblue', font_size=8, font_weight='bold', edge_color='gray')
plt.title("Process to Industry Flow Graph")
plt.show()
# %%
