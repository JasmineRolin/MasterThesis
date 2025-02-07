import pandas as pd
import folium
from folium.plugins import HeatMap
import matplotlib.pyplot as plt

# Load the data from a CSV file
df = pd.read_csv('../Melbourne_Data/Ridesharing_S_1.csv')


## ----------------------- Heatmap of Pickup Locations ----------------------- ##
# Extract Origin Latitude and Longitude for the heatmap
locations = df[["Origin_Latitude", "Origin_Longitude"]].values.toVector()

# Create a folium map centered around the average location
map_center = [df["Origin_Latitude"].mean(), df["Origin_Longitude"].mean()]
m = folium.Map(location=map_center, zoom_start=12)

# Add the heatmap to the map
HeatMap(locations).add_to(m)

# Save the map to an HTML file
m.save("pickup_heatmap.html")

print("Heatmap created and saved as 'pickup_heatmap.html'. Open this file to view the map.")

## ----------------------- Heatmap of Dropoff Locations ----------------------- ##
# Extract Destination Latitude and Longitude for the heatmap    
locations = df[["Destination_Latitude", "Destination_Longitude"]].values.toVector()

# Create a folium map centered around the average location
map_center = [df["Destination_Latitude"].mean(), df["Destination_Longitude"].mean()]
m = folium.Map(location=map_center, zoom_start=12)

# Add the heatmap to the map
HeatMap(locations).add_to(m)

# Save the map to an HTML file
m.save("dropoff_heatmap.html")

print("Heatmap created and saved as 'dropoff_heatmap.html'. Open this file to view the map.")

## ----------------------- Histrogram of Latest Arrival ----------------------- ##
# Create a histogram of the pickup times
df["Latesttime"] = pd.to_datetime(df["Latesttime"])
df["Latesttime"].dt.hour.hist(bins=24, rwidth=0.8, color='skyblue')
plt.xlabel("Hour of the day")
plt.ylabel("Number of rides")
plt.title("Histogram of Latest Arrival Times")
plt.show()
