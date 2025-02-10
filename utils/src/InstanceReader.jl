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

    # Get vehicles 
    vehicles = readVehicles(vehiclesDf,nVehicles,nRequests)

    scenario = Scenario([], vehicles, 0.0f0, 0.0f0, Dict(), TimeWindow(0, 0))

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







end