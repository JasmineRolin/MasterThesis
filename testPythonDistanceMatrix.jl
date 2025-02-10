using PyCall

# Import the required Python libraries
osmnx = pyimport("osmnx")
nx = pyimport("networkx")

# Function to compute the distance matrix in Python
function get_distance_matrix_python(vehicle_positions, locations, graph)
    dist_matrix = []
    
    for vehicle in vehicle_positions
        row = []
        for location in locations
            # Calculate the nearest nodes for both the vehicle and the location
            nearest_vehicle_node = osmnx.distance.nearest_nodes(graph, vehicle[1], vehicle[2])
            nearest_location_node = osmnx.distance.nearest_nodes(graph, location[1], location[2])

            # Compute the shortest path distance using osmnx
            distance = nx.distance.shortest_path_length(graph, nearest_vehicle_node, nearest_location_node)
            push!(row, distance)
        end
        push!(dist_matrix, row)
    end

    return dist_matrix
end

# Example vehicle positions and locations (latitude, longitude)
vehicle_positions = [(59.91, 10.74), (60.19, 10.70), (59.93, 10.75)]  # 3 vehicles
locations = [(59.92, 10.73), (60.00, 10.77), (59.95, 10.80)]         # 3 locations

# Download the OSM graph for a region of interest (for example, a small area in Norway)
place_name = "Oslo, Norway"
graph = osmnx.graph_from_place(place_name, network_type="drive")

println("Data is loaded")

# Compute the distance matrix
dist_matrix = get_distance_matrix_python(vehicle_positions, locations, graph)

# Print the resulting distance matrix
println(dist_matrix)