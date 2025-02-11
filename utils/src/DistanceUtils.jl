module DistanceUtils

using PyCall, domain

export getDistanceAndTimeMatrix

function getDistanceAndTimeMatrix(scenario::Scenario)::Tuple{Array{Int, 2}, Array{Int, 2}}
    # Ensure Julia can find the Python script
    push!(pyimport("sys")."path", "utils/src")  

    # Import the py module 
    osrm = pyimport("DistanceCalculator")  


    # Collect request info 
    pickUpLocations = [(r.pickupLocation.lat,r.pickupLocation.long) for r in scenario.requests]
    dropOffLocations = [(r.dropOffLocation.lat,r.dropOffLocation.long) for r in scenario.requests]

    # Collect depot info
    depotLocations = Vector{Tuple{Float64, Float64}}()
    depotIds = Set{Int}()
    for veh in scenario.vehicles
        if !(veh.depotId in depotIds)
            push!(depotIds,veh.depotId)
            push!(depotLocations,(veh.depotLocation.lat,veh.depotLocation.long))
        end
    end

    # Initialize the distance matrix
    locations = [pickUpLocations;dropOffLocations;depotLocations]
    nLocations = length(locations)

    distanceMatrix = zeros(Int,nLocations,nLocations)
    travelTimeMatrix = zeros(Int,nLocations,nLocations)

    # Use parallelization to compute the distances (if possible, depending on your system)
    for (i,loc1) in enumerate(locations)
        for (j,loc2) in enumerate(locations)
            if i == j 
                distanceMatrix[i,j] = 0
                travelTimeMatrix[i,j] = 0
            else
                dist, time = osrm.fetch_distance_travel_time_osrm(loc1, loc2)
                distanceMatrix[i,j] = ceil(dist)
                travelTimeMatrix[i,j] = ceil(time)
            end
        end
    end

    return distanceMatrix, travelTimeMatrix
end

end