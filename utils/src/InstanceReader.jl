module InstanceReaders 

using DataFrames, CSV, domain
using ..utils


export readInstance
export readVehicles
export readRequests
export splitRequests

#==
 Function to read instance 
 Takes request, vehicles and parameters .csv as input 
==#
function readInstance(requestFile::String, vehicleFile::String, parametersFile::String,distanceMatrixFile=""::String,timeMatrixFile=""::String)::Scenario

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
   

    # Read request, vehicle and parameters dataframes from input
    requestsDf = CSV.read(requestFile, DataFrame)
    vehiclesDf = CSV.read(vehicleFile, DataFrame)
    parametersDf = CSV.read(parametersFile, DataFrame)
    nRequests = nrow(requestsDf)
    
    # Get parameters 
    planningPeriod = TimeWindow(parametersDf[1,"start_of_planning_period"],parametersDf[1,"end_of_planning_period"])
    serviceTimes = Dict{MobilityType,Int}(WALKING => parametersDf[1,"service_time_walking"], WHEELCHAIR => parametersDf[1,"service_time_wheelchair"])
    vehicleCostPrHour = Float64(parametersDf[1,"vehicle_cost_pr_hour"])
    vehicleStartUpCost = Float64(parametersDf[1,"vehicle_start_up_cost"])
    bufferTime = parametersDf[1,"buffer_time"]
    maximumRideTimePercent = parametersDf[1,"maximum_ride_time_percent"]
    minimumMaximumRideTime = parametersDf[1,"minimum_maximum_ride_time"]
    

    # Get vehicles 
    vehicles,depots, depotLocations = readVehicles(vehiclesDf,nRequests)
    nDepots = length(depots)

    # Read time and distance matrices from input or initialize empty matrices
    distance, time = getDistanceAndTimeMatrix(distanceMatrixFile,timeMatrixFile,requestFile,collect(keys(depotLocations)))

    # Get requests 
    requests = readRequests(requestsDf,nRequests,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time)

    # Split into offline and online requests
    onlineRequests, offlineRequests = splitRequests(requests)

    # Get distance and time matrix
    scenario = Scenario(requests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,distance,time,nDepots,depots)

    return scenario

end


#==
 Function to read vehicles  
==#
function readVehicles(vehiclesDf::DataFrame, nRequests::Int)
    # Get vehicles
    vehicles = Vector{Vehicle}()
    depotLocations = Dict{Tuple{Float64,Float64},Int}() # Keep track of depots to give them an Id 
    depotDictionary = Dict{Int, Vector{Int}}()

    currentDepotId = 2*nRequests + 1
    nDepots = 0
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

        depotId = get!(depotLocations, (depotLatitude, depotLongitude), currentDepotId) # Get or default
        if depotId == currentDepotId  
            currentDepotId += 1
            nDepots += 1
        end

        # Add depot to dictionary
        if haskey(depotDictionary, depotId)
            push!(depotDictionary[depotId], id)  # Append vehicle ID to existing vector
        else
            depotDictionary[depotId] = [id]  # Create new vector with the first vehicle ID
        end

        depotLocation = Location(string("Depot ",depotId),depotLatitude,depotLongitude)

        # Create vehicle 
        vehicle = Vehicle(id,availableTimeWindow,depotId,depotLocation,maximumRideTime,capacities,totalCapacity)
        push!(vehicles,vehicle)
        
    end

    return vehicles, depotDictionary, depotLocations 
end


#==
 Function to read requests 
==#
function readRequests(requestDf::DataFrame,nRequests::Int, bufferTime::Int,maximumRideTimePercent::Int, minimumMaximumRideTime::Int,time::Array{Int,2})
    requests = Vector{Request}()

    for row in eachrow(requestDf)
        id = row.id 
        dropOffId = nRequests + id

        # Read location 
        pickUpLocation = Location(string("PU R",id),row.pickup_latitude,row.pickup_longitude) 
        dropOffLocation = Location(string("DO R",id),row.dropoff_latitude,row.dropoff_longitude) 

        # Read request type 
        requestType = row.request_type == 1 ? PICKUP_REQUEST : DROPOFF_REQUEST

        # Read mobility type 
        mobilityType = row.mobility_type == "Walking" ? WALKING : WHEELCHAIR

        # Read call time 
        callTime = Int(floor(row.call_time))

        # Read request time 
        requestTime = row.request_time 

        if callTime > requestTime - bufferTime
            throw(ArgumentError(string("Call time is not before required buffer period for request: ",id)))
        end

        # Read maximum drive time 
        directDriveTime = time[id,dropOffId]
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
        dropOffActivity = Activity(dropOffId,id,DROPOFF,mobilityType,dropOffLocation,dropOffTimeWindow)
        request = Request(id,requestType,mobilityType,callTime,pickUpActivity,dropOffActivity,directDriveTime,maximumRideTime)

        push!(requests,request)
    end


    return requests
end


#==
 Function to split requests into online and offline requests
==#
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


end