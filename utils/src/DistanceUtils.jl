module DistanceUtils

using PyCall, DataFrames, CSV,domain

export getDistanceAndTimeMatrix,getDistanceAndTimeMatrixFromLocations

#==
 Function to read or calculate distance and time matrix
==#
function getDistanceAndTimeMatrix(distanceMatrixFile=""::String,timeMatrixFile=""::String,requestFile=""::String,depotLocations=Vector{Tuple{Float64,Float64}}()::Vector{Tuple{Float64,Float64}})::Tuple{Array{Float64, 2}, Array{Int, 2}}
    if distanceMatrixFile != "" && !isfile(distanceMatrixFile)
        error("Error: distanceMatrixFile file $distanceMatrixFile does not exist.")
    end
    if timeMatrixFile != "" && !isfile(timeMatrixFile)
        error("Error: timeMatrixFile file $timeMatrixFile does not exist.")
    end 

    # Read time and distance file if given else calculate
    if distanceMatrixFile != "" && timeMatrixFile != ""
        lines = readlines(distanceMatrixFile)
        distance = [parse.(Float64, split(line)) for line in lines]
        distance = convert(Matrix{Float64}, hcat(distance...)')

        lines = readlines(timeMatrixFile)
        time = [parse.(Int, split(line)) for line in lines]
        time = convert(Matrix{Int}, hcat(time...)')

        return distance, time
    end 

    # Calculate distance and time 
    requestsDf = CSV.read(requestFile, DataFrame)

    return getDistanceAndTimeMatrixFromDataFrame(requestsDf,depotLocations)
end


#==
#  Function to get distance and time matrix from data frame and depot location dictionary 
==#
function getDistanceAndTimeMatrixFromDataFrame(requestsDf::DataFrame,depotLocations::Vector{Tuple{Float64,Float64}})::Tuple{Array{Float64, 2}, Array{Int, 2}}
    # Collect request info 
    pickUpLocations = [(r.pickup_latitude,r.pickup_longitude) for r in eachrow(requestsDf)]
    dropOffLocations = [(r.dropoff_latitude,r.dropoff_longitude)  for r in eachrow(requestsDf)]

    # Collect all locations
    locations = [pickUpLocations;dropOffLocations;depotLocations]

    return getDistanceAndTimeMatrixFromLocations(locations)
end


#==
#  Function to get distance and time matrix
==#
function getDistanceAndTimeMatrixFromLocations(locations::Vector{Tuple{Float64, Float64}})::Tuple{Array{Float64, 2}, Array{Int, 2}}
    # Ensure Julia can find the Python script
    push!(pyimport("sys")."path", "utils/src")  

    # Import the py module 
    osrm = pyimport("DistanceCalculator")  

    # Initialize
    nLocations = length(locations)

    distanceMatrix = zeros(Float64,nLocations,nLocations)
    travelTimeMatrix = zeros(Int,nLocations,nLocations)

    # Compute the distances 
    for (i,loc1) in enumerate(locations)
        for (j,loc2) in enumerate(locations)
            if i == j 
                distanceMatrix[i,j] = 0
                travelTimeMatrix[i,j] = 0
            else
                dist, time = osrm.fetch_distance_travel_time_osrm(loc1, loc2)
                distanceMatrix[i,j] = dist/1000.0
                travelTimeMatrix[i,j] = ceil(time)
            end
        end
    end

    return distanceMatrix, travelTimeMatrix
end

end