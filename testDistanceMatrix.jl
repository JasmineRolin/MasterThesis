

using OpenStreetMapX
using utils


# Example mock data (latitude, longitude)
vehicle_positions = [(59.91, 10.74), (60.19, 10.70), (59.93, 10.75)]  # 3 vehicles
locations = [(59.92, 10.73), (60.00, 10.77), (59.95, 10.80)]         # 3 locations

println("START")

# Load OpenStreetMap data
map_file = "C:/Users/Astrid/Downloads/planet_10.494,59.879_11.066,60.058.osm.pbf"
osm_data = OpenStreetMapX.parsePBF(map_file)
println("DATA IS LOADED")


# Compute the distance matrix
distMatrix = getDistanceMatrix(vehicle_positions, locations, osm_data)
