module InstanceReaders 

using DataFrames, CSV, domain

export readInstance

#==
 Function to read instance 
 Takes request, vehicles and parameters .csv as input 
==#
function readInstance(requestFile::String, vehicleFile::String, parametersFile::String)::Scenario

    # Check that files exist 
    if !isfile(requestFile)
        error("Error: Request file $requestFile does not exist.")
    end
    if !isfile(vehicleFile)
        error("Error: Vehicle file $vehicleFile does not exist.")
    end
    if !isfile(parametersFile)
        error("Error: Parameters file $parametersFile does not exist.")
    end

    # Read input 
    requestsDf = CSV.read(requestFile, DataFrame)
    vehiclesDf = CSV.read(vehicleFile, DataFrame)
    parametersDf = CSV.read(parametersFile, DataFrame)

    nRequests = nrow(requestsDf)
    nVehicles = nrow(vehiclesDf)
    
    # Get parameters 
    planningPeriod = TimeWindow(parametersDf[1,"start_of_planning_period"],parametersDf[1,"end_of_planning_period"])
    serviceTimes = Dict{MobilityType,Int}(WALKING => parametersDf[1,"service_time_walking"], WHEELCHAIR => parametersDf[1,"service_time_wheelchair"])
    vehicleCostPrHour = parametersDf[1,"vehicle_cost_pr_hour"]
    vehicleStartUpCost = parametersDf[1,"vehicle_start_up_cost"]
    bufferTime = parametersDf[1,"buffer_time"]
    maximumRideTimePercent = parametersDf[1,"maximum_ride_time_percent"]
    minimumMaximumRideTime = parametersDf[1,"minimum_maximum_ride_time"]
    

    # Get vehicles 
    vehicles = readVehicles(vehiclesDf,nVehicles,nRequests)

    # Get requests 
    requests = readRequests(requestsDf,bufferTime,maximumRideTimePercent,minimumMaximumRideTime)

    # Split into offline and online requests
    onlineRequests, offlineRequests = splitRequests(requests)

    scenario = Scenario(requests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime)

    return scenario

end


#==
 Function to read vehicles  
==#
function readVehicles(vehiclesDf::DataFrame,nVehicles::Int, nRequests::Int)::Vector{Vehicle}
    # Get vehicles
    vehicles = Vector{Vehicle}()
    depots = Dict{Tuple{Float64,Float64},Int}() # Keep track of depots to give them an Id 

    currentDepotId = 2*nRequests + 1
    for row in eachrow(vehiclesDf)
        id = row.id

        # Read time window 
        availableTimeWindow = TimeWindow(row.start_of_availability,row.end_of_availability)

        # Read maximum ride time 
        maximumRideTime = row.maximum_ride_time
        
        # Read capacities 
        capacities = Dict{MobilityType,Int}(WALKING => row.capacity_walking, WHEELCHAIR => row.capacity_wheelchair)
        totalCapacity = row.capacity_walking + row.capacity_wheelchair

        # Read depot 
        depotLatitude = row.depot_latitude 
        depotLongitude = row.depot_longitude 

        depotId = get!(depots, (depotLatitude, depotLongitude), currentDepotId) # Get or default
        if depotId == currentDepotId  
            currentDepotId += 1
        end

        depotLocation = Location(string("Depot ",depotId),depotLatitude,depotLongitude)

        # Create vehicle 
        vehicle = Vehicle(id,availableTimeWindow,depotId,depotLocation,maximumRideTime,capacities,totalCapacity)
        push!(vehicles,vehicle)
        
    end

    return vehicles
end


#==
 Function to read requests 
==#
function readRequests(requestDf::DataFrame, bufferTime::Int,maximumRideTimePercent::Int, minimumMaximumRideTime::Int)::Vector{Request}
    requests = Vector{Request}()
   
    for row in eachrow(requestDf)
        id = row.id 

        # Read location 
        pickUpLocation = Location(string("PU R",id),row.pickup_latitude,row.pickup_longitude) 
        dropOffLocation = Location(string("DO R",id),row.dropoff_latitude,row.dropoff_longitude) 

        # Read request type 
        requestType = row.request_type == 1 ? PICKUP_REQUEST : DROPOFF_REQUEST

        # Read mobility type 
        mobilityType = row.mobility_type == "Walking" ? WALKING : WHEELCHAIR

        # Read call time 
        callTime = floor(row.call_time)

        # Read request time 
        requestTime = row.request_time 

        if callTime > requestTime - bufferTime
            throw(ArgumentError(string("Call time is not before required buffer period for request: ",id)))
        end

        # Read maximum drive time 
        directDriveTime = computeDirectDriveTime(pickUpLocation,dropOffLocation)
        maximumRideTime = findMaximumRideTime(directDriveTime,maximumRideTimePercent,minimumMaximumRideTime)

        if directDriveTime >= maximumRideTime
            throw(ArgumentError(string("Direct drive time is larger than maximum ride time: ",id)))
        end

        # Create time windows 
        pickUpTimeWindow = TimeWindow(0,0)
        dropOffTimeWindow = TimeWindow(0,0)

        if requestType == PICKUP_REQUEST
            pickUpTimeWindow = findTimeWindowOfRequestedPickUpTime(requestTime)
            dropOffTimeWindow = findTimeWindowOfDropOff(pickUpTimeWindow,directDriveTime,maximumRideTime)
        else
            dropOffTimeWindow = findTimeWindowOfRequestedDropOffTime(requestTime)
            pickUpTimeWindow = findTimeWindowOfPickUp(dropOffTimeWindow,directDriveTime,maximumRideTime)
        end

        pickUpActivity = Activity(id,id,PICKUP,mobilityType,pickUpLocation,pickUpTimeWindow)
        dropOffActivity = Activity(2*id,id,DROPOFF,mobilityType,dropOffLocation,dropOffTimeWindow)
        request = Request(id,requestType,mobilityType,callTime,pickUpActivity,dropOffActivity,directDriveTime,maximumRideTime)
        push!(requests,request)
        
    end


    return requests
end


# ------
# Function to split requests into online and offline requests
# ------
function splitRequests(requests::Vector{Request})

    onlineRequests = Request[]
    offlineRequests = Request[]

    for (~,r) in enumerate(requests)
        if r.callTime == 0
            push!(offlineRequests, r)
        else
            push!(onlineRequests, r)
        end
    end

    sort!(onlineRequests, by = x -> x.callTime)

    return onlineRequests, offlineRequests

end


# TODO: remove when distance function is working 
using .MathConstants: pi

function haversine_distance(lat1::Float64, long1::Float64, lat2::Float64, long2::Float64)::Float64
    EARTH_RADIUS_KM = 6371.0

    # Convert degrees to radians
    φ1, φ2 = deg2rad(lat1), deg2rad(lat2)
    Δφ = deg2rad(lat2 - lat1)
    Δλ = deg2rad(long2 - long1)

    # Haversine formula
    a = sin(Δφ / 2)^2 + cos(φ1) * cos(φ2) * sin(Δλ / 2)^2
    c = 2 * atan(sqrt(a), sqrt(1 - a))

    return EARTH_RADIUS_KM * c  # Distance in km
end

function computeDirectDriveTime(location1::Location, location2::Location)::Int
    distance_km = haversine_distance(location1.lat, location1.long, location2.lat, location2.long)
    return 10*ceil(distance_km)  # Assuming time is proportional to distance
end



end