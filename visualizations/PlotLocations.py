import pandas as pd
import folium
from folium.plugins import HeatMap
import numpy as np

# Read data 
file_path = "Data/Konsentra/Data.xlsx"
df = pd.read_excel(file_path, engine='openpyxl')

## ----------------------- Heatmap of Pickup Locations ----------------------- ##
# Initialize lists for pickup and dropoff locations
pickUpLocations = []
deliveryLocations = []
unique_customers = set()

# Loop over the dataframe rows
for _, row in df.iterrows():
    if row["Age"] >= 20:
        customerId = row['ClientID']
        
        if customerId not in unique_customers:
            unique_customers.add(customerId)  # Track unique customers
            
            if not np.isnan(row['From LAT']) and not np.isnan(row['From LON']):
                pickUpLocations.append([row['From LAT'], row['From LON']])
            
            if not np.isnan(row['To LAT']) and not np.isnan(row['To LON']):
                deliveryLocations.append([row['To LAT'], row['To LON']])

print("number of locations: ", len(pickUpLocations))

# Ensure data exists before processing
if pickUpLocations:
    # Compute map center
    map_center = np.mean(pickUpLocations, axis=0)

    # Create map and add heatmap
    pickup_map = folium.Map(location=map_center, zoom_start=12)
    HeatMap(pickUpLocations).add_to(pickup_map)

    # Save and notify
    pickup_map.save("pickup_heatmap.html")
    print("Pickup heatmap created and saved as 'pickup_heatmap.html'.")
else:
    print("No valid pickup locations found.")

## ----------------------- Heatmap of Dropoff Locations ----------------------- ##
if deliveryLocations:
    map_center = np.mean(deliveryLocations, axis=0)
    
    dropoff_map = folium.Map(location=map_center, zoom_start=12)
    HeatMap(deliveryLocations).add_to(dropoff_map)
    
    dropoff_map.save("dropoff_heatmap.html")
    print("Dropoff heatmap created and saved as 'dropoff_heatmap.html'.")
else:
    print("No valid dropoff locations found.")


## ----------------------- Histrogram of Latest Arrival ----------------------- ##
# Create a histogram of the pickup times
# df["Latesttime"] = pd.to_datetime(df["Latesttime"])
# df["Latesttime"].dt.hour.hist(bins=24, rwidth=0.8, color='skyblue')
# plt.xlabel("Hour of the day")
# plt.ylabel("Number of rides")
# plt.title("Histogram of Latest Arrival Times")
# plt.show()
