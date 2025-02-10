module DistanceMatrix

using OpenStreetMapX
export getDistanceMatrix

#
#map_file = "path_to_your/norway-latest.osm.pbf"
#osm_data = OpenStreetMapX.parseOSM(map_file)

function getDistanceMatrix(VehiclePositions, Locations, osm_data)

    # Now use OpenStreetMapX's nearest_node method to find the nearest nodes
    vehicle_nodes = [OpenStreetMapX.nearest_node(osm_data, ENU(pos[1], pos[2], 0)) for pos in VehiclePositions]
    location_nodes = [OpenStreetMapX.nearest_node(osm_data, ENU(loc[1], loc[2], 0)) for loc in Locations]

    # Initialize the distance matrix
    distMatrix = zeros(Float64, length(VehiclePositions), length(Locations))

    # Use parallelization to compute the distances (if possible, depending on your system)
    for i in 1:length(VehiclePositions)
        for j in 1:length(Locations)
            distMatrix[i,j] = OpenStreetMapX.shortest_route(osm_data, vehicle_nodes[i], location_nodes[j])
        end
    end

    return distMatrix
end

end