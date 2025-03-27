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
                dist, time = haversine_distance(loc1[1],loc1[2],loc2[1],loc2[2])
                distanceMatrix[i,j] = dist
                travelTimeMatrix[i,j] = ceil(time)
            end
        end
    end

    return distanceMatrix, travelTimeMatrix
end

#==
# Haversine distance between two points
==#
function haversine_distance(lat1, lon1, lat2, lon2; speedKmh=60.0)
    # Earth's radius in kilometers
    R = 6371.0

    # Convert degrees to radians
    lat1 = deg2rad(lat1)
    lon1 = deg2rad(lon1)
    lat2 = deg2rad(lat2)
    lon2 = deg2rad(lon2)

    dlat = lat2 - lat1
    dlon = lon2 - lon1

    # Haversine formula
    a = sin(dlat/2)^2 + cos(lat1) * cos(lat2) * sin(dlon/2)^2
    c = 2 * atan(sqrt(a), sqrt(1 - a))

    # Distance in kilometers
    distanceKm = R * c

    # Time in hours (assuming constant speed)
    timeHours = distanceKm / speedKmh

    return distanceKm, timeHours*60
end

end