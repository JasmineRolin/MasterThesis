import osmnx as ox
import networkx as nx

def get_distance_matrix_python(vehicle_positions, locations, graph):
    dist_matrix = []

    for vehicle in vehicle_positions:
        row = []
        for location in locations:
            # Calculate the nearest nodes for both the vehicle and the location
            nearest_vehicle_node = ox.distance.nearest_nodes(graph, vehicle[1], vehicle[0])
            nearest_location_node = ox.distance.nearest_nodes(graph, location[1], location[0])

            # Compute the shortest path distance using osmnx
            try:
                distance = nx.shortest_path_length(graph, nearest_vehicle_node, nearest_location_node, weight='length')
            except Exception as e:
                distance = float('inf')  # Handle disconnected nodes
                print(f"Error calculating distance: {e}")
            row.append(distance)

        dist_matrix.append(row)

    return dist_matrix


# Example vehicle positions and locations (latitude, longitude)
vehicle_positions = [(59.91, 10.74), (60.19, 10.70), (59.93, 10.75)]  # 3 vehicles
locations = [(59.92, 10.73), (60.00, 10.77), (59.95, 10.80)]         # 3 locations

# Download the OSM graph for a region of interest (for example, Oslo, Norway)
place_name = "Oslo, Norway"
graph = ox.graph_from_place(place_name, network_type="drive")

print("Data is loaded")

# Compute the distance matrix
dist_matrix = get_distance_matrix_python(vehicle_positions, locations, graph)

# Print the resulting distance matrix
print("Distance matrix (in meters):")
for row in dist_matrix:
    print(row)
