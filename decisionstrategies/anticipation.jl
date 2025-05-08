using offlinesolution
using domain
using utils
using DataFrames
using CSV
using alns
using Test
using TimerOutputs

global GENERATE_SIMULATION_DATA = false
global GENERATE_DATA_AND_VEHICLES = true
global GENERATE_VEHICLES = false

#==
# Constants for data generation 
==#
global DoD = 0.4 # Degree of dynamism
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global callBuffer = 2*60 # 2 hours buffer
global nData = 10
global nRequestList = [20] #[20,100,300,500]
global MAX_DELAY = 15 # TODO Astrid I just put something

#==
# Constant for vehicle generation  
==#
global vehicleCapacity = 4
global GammaList = [0.5,0.7,0.9]

global shifts = Dict(
    "Morning"    => Dict("TimeWindow" => [6*60, 12*60], "cost" => 2.0, "nVehicles" => 0, "y" => []),
    "Noon"       => Dict("TimeWindow" => [10*60, 16*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Afternoon"  => Dict("TimeWindow" => [14*60, 20*60], "cost" => 3.0, "nVehicles" => 0, "y" => []),
    "Evening"    => Dict("TimeWindow" => [18*60, 24*60], "cost" => 4.0, "nVehicles" => 0, "y" => [])
)


#==
# Grid constants 
==#
global MAX_LAT = 60.721
global MIN_LAT = 59.165
global MAX_LONG = 12.458
global MIN_LONG = 9.948
global NUM_ROWS = 5
global NUM_COLS = 5


#==
# Common 
==#
global time_range = collect(range(6*60,23*60))


include("../dataexploration/GenerateLargeDataSets.jl")



function createExpectedRequests(N::Int,nFixedRequests::Int)
    
    # Initialize variables
    expectedRequests = Vector{Request}(undef, N)
    expectedRequestIds = Vector{Int}(undef, N)
    requestDF = DataFrame(
        id = Int[],
        pickup_latitude = Float64[],
        pickup_longitude = Float64[],
        dropoff_latitude = Float64[],
        dropoff_longitude = Float64[],
        request_type = Int[],
        request_time = Int[],
        mobility_type = String[],
        call_time = Int[],
        direct_drive_time = Int[],
    )

    probabilities_pickUpTime,probabilities_dropOffTime,_,_,probabilities_location,_,x_range,y_range,probabilities_distance,_,distance_range,_,_,_,_,_= load_simulation_data("Data/Simulation data/")
    time_range = collect(range(6*60,23*60))
    max_lat, min_lat, max_long, min_long = MAX_LAT, MIN_LAT, MAX_LONG, MIN_LONG

    # Generate expected request DF
    for i in 1:N
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance,max_lat, min_lat, max_long, min_long)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]


        # Determine type of request
        if rand() < 0.5
            requestType = 0  # pick-up request

            sampled_indices = sample(1:length(probabilities_pickUpTime), Weights(probabilities_pickUpTime), 1)
            sampledTimePick = time_range[sampled_indices]
            requestTime = ceil(sampledTimePick[1])
        else
            requestType = 1  # drop-off request

            # Direct drive time 
            directDriveTime = ceil(haversine_distance(pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude)[2])

            # Earliest request time 
            earliestRequestTime = serviceWindow[1] + directDriveTime + MAX_DELAY
            indices = time_range .>= earliestRequestTime
            nTimes = sum(indices)

            sampled_indices = sample(1:nTimes, Weights(probabilities_dropOffTime[indices]), 1)
            sampledTimeDrop = time_range[indices][sampled_indices]
            requestTime = ceil(sampledTimeDrop[1])
        end

        push!(requestDF, (i, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, requestType, requestTime,"WALKING",0,0))
        append!(expectedRequestIds, i+nFixedRequests)
        
    
    end

    return requestDF

end

function getDistanceAndTimeMatrixFromDataFrame(requestsDf::DataFrame,expectedRequestsDf::DataFrame,depotLocations::Vector{Tuple{Float64,Float64}})::Tuple{Array{Float64, 2}, Array{Int, 2}}
    # Collect request info 
    pickUpLocations = [(r.pickup_latitude,r.pickup_longitude) for r in eachrow(requestsDf)]
    dropOffLocations = [(r.dropoff_latitude,r.dropoff_longitude)  for r in eachrow(requestsDf)]

    # Collect expected request info
    expectedPickUpLocations = [(r.pickup_latitude,r.pickup_longitude) for r in eachrow(expectedRequestsDf)]
    expectedDropOffLocations = [(r.dropoff_latitude,r.dropoff_longitude)  for r in eachrow(expectedRequestsDf)]

    # Collect all locations
    locations = [pickUpLocations;expectedPickUpLocations;dropOffLocations;expectedDropOffLocations;depotLocations]

    return getDistanceAndTimeMatrixFromLocations(locations)
end


function readInstanceAnticipation(requestFile::String,nNewExpected::Int, vehicleFile::String, parametersFile::String,scenarioName=""::String)

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
    serviceTimes = parametersDf[1,"service_time_walking"]
    vehicleCostPrHour = Float64(parametersDf[1,"vehicle_cost_pr_hour"])
    vehicleStartUpCost = Float64(parametersDf[1,"vehicle_start_up_cost"])
    bufferTime = parametersDf[1,"buffer_time"]
    maximumRideTimePercent = parametersDf[1,"maximum_ride_time_percent"]
    minimumMaximumRideTime = parametersDf[1,"minimum_maximum_ride_time"]
    taxiParameter = Float64(parametersDf[1,"taxi_parameter"])
    taxiParameterExpected = Float64(parametersDf[1,"taxi_parameter_expected"])
    

    # Get vehicles # TODO change output
    vehicles,depots, depotLocations = readVehicles(vehiclesDf,nRequests+nNewExpected)
    nDepots = length(depots)

    # Generate expected requests
    newExpectedRequestsDf = createExpectedRequests(nNewExpected,nRequests)

    # Read time and distance matrices from input or initialize empty matrices
    distance, time = getDistanceAndTimeMatrixFromDataFrame(requestsDf,newExpectedRequestsDf,collect(keys(depotLocations)))

    # Get requests 
    requests = readRequests(requestsDf,nRequests+nNewExpected,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time)
    expectedRequests = readRequests(newExpectedRequestsDf,nNewExpected,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time,extraN=nRequests)
    allRequests = vcat(requests, expectedRequests)

    # Split into offline and online requests
    onlineRequests, offlineRequests = splitRequests(allRequests)

    # Get distance and time matrix # TODO add grid?
    scenario = Scenario(scenarioName,allRequests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,distance,time,nDepots,depots,taxiParameter,nNewExpected,taxiParameterExpected,nRequests)

    return scenario

end


function removeExpectedRequestsFromSolution!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},solution::Solution,nExpected::Int,nFixed::Int,nNotServicedExpectedRequests::Int,requestBank::Vector{Int},taxiParameter::Float64,taxiParameterExpected::Float64;TO::TimerOutput=TimerOutput())
    
    # Determine remaining requests to remove
    requestsToRemove = Set{Int}()
    for i in (nFixed+1):(nFixed+nExpected)
        if i in requestBank
            continue
        end
        # Add to remaining requests
        push!(requestsToRemove, i)
    end

    # Choice of removal of activity
    remover = removeRequestsFromScheduleAnticipation!
    removeRequestsFromSolution!(time,distance,serviceTimes,requests,solution,requestsToRemove,remover=remover,nFixed=nFixed,nExpected=nExpected)
    updateExpectedWaiting!(time,distance,serviceTimes,solution,taxiParameter,taxiParameterExpected,nFixed=nFixed,nExpected=nExpected)

    # Remove taxis for expected requests
    solution.nTaxiExpected -= nNotServicedExpectedRequests
    solution.totalCost -= nNotServicedExpectedRequests * taxiParameterExpected


end


#-----------
# Function to remove expected requests from schedule and insert waiting activities instead
#-----------
function removeRequestsFromScheduleAnticipation!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},schedule::VehicleSchedule,requestsToRemove::Vector{Int},visitedRoute::Dict{Int, Dict{String, Int}},scenario::Scenario;TO::TimerOutput=TimerOutput(),nFixed::Int=0,nExpected::Int=0)

    # Remove requests from schedule
    for requestToRemove in requestsToRemove
        # Find positions of pick up and drop off activity   
        pickUpPosition,dropOffPosition = findPositionOfRequest(schedule,requestToRemove)

        # Remove pickup activity 
        newPickUpIdx, routeReductionPickUp = removeExpectedActivityFromRouteWF!(time,schedule,pickUpPosition)

        # Remove drop off activity 
        newDropOffIdx, _ = removeExpectedActivityFromRouteWF!(time,schedule,dropOffPosition-routeReductionPickUp)

        # Update capacity
        for idx in newPickUpIdx+1:newDropOffIdx
            schedule.numberOfWalking[idx] -= 1
        end

    end

    # Update KPIs # TODO skal tilføjes når uppdateExpectedWaiting! fjernes
    #schedule.totalDistance = getTotalDistanceRoute(schedule.route,distance)
    #schedule.totalIdleTime = getTotalIdleTimeRoute(schedule.route) 
    #schedule.totalCost = getTotalCostRouteOnline(time,schedule.route,visitedRoute,serviceTimes)

end


function removeExpectedActivityFromRouteWF!(time::Array{Int,2}, schedule::VehicleSchedule, idx::Int)
    route = schedule.route
    numberOfWalking = schedule.numberOfWalking

    # Find number of WAITING activities before idx
    nActivitiesBefore = 0
    for i in (idx-1):-1:1
        if route[i].activity.activityType == WAITING
            nActivitiesBefore += 1
        else
            break
        end
    end

    # Find number of WAITING activities after idx
    nActivitiesAfter = 0
    for i in idx+1:length(route)
        if route[i].activity.activityType == WAITING
            nActivitiesAfter += 1
        else
            break
        end
    end

    idxStart = idx - nActivitiesBefore
    idxEnd = idx + nActivitiesAfter

    # Route reduction
    routeReduction = idxEnd - idxStart

    # Extract activities before and after the activity to remove and the waiting activities
    activityAssignmentBefore = route[idxStart - 1]
    activityAssignmentAfter = route[idxEnd + 1]

    # Remove expected activities and consecutive waiting activities 
    for _ in idxStart:idxEnd
        deleteat!(route, idxStart)
        deleteat!(numberOfWalking, idxStart)
    end

    # Insert WAITING activity
    startOfWaitingActivity = activityAssignmentBefore.endOfServiceTime
    endOfWaitingActivity = activityAssignmentAfter.startOfServiceTime -time[activityAssignmentBefore.activity.id, activityAssignmentAfter.activity.id]
    waitingActivity = Activity(activityAssignmentBefore.activity.id,-1,WAITING,activityAssignmentBefore.activity.location,TimeWindow(startOfWaitingActivity, endOfWaitingActivity))
    waitingAssignment = ActivityAssignment(waitingActivity,activityAssignmentBefore.vehicle,startOfWaitingActivity,endOfWaitingActivity)

    insert!(route, idxStart, waitingAssignment)
    insert!(numberOfWalking, idxStart, numberOfWalking[idxStart-1])

    return idxStart, routeReduction
end


#-------
# Function to update expected waiting activities in solution so they have location as the activity right before
#-------
function updateExpectedWaiting!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,solution::Solution,taxiParameter::Float64,taxiParameterExpected::Float64;nFixed::Int=0,nExpected::Int=0)

    # Update solution
    solution.totalDistance = 0.0
    solution.totalIdleTime = 0
    solution.totalCost = solution.nTaxi * taxiParameter + solution.nTaxiExpected * taxiParameterExpected

    for schedule in solution.vehicleSchedules

        # Change location of lonely waiting nodes with expected request location (Comes from ALNS)
        for idx in 2:length(schedule.route)-1
            activity = schedule.route[idx].activity
            activityAssignment = schedule.route[idx]
            activityAssignmentBefore = schedule.route[idx-1]
            activityBefore = activityAssignmentBefore.activity
            activityAssignmentAfter = schedule.route[idx+1]
            id = activity.id
        
            isLocationExpected = (id > nFixed && id <= nFixed + nExpected) || (id > 2*nFixed + nExpected && id <= 2*nFixed + 2*nExpected)
            if activity.activityType == WAITING && isLocationExpected  
                activity.location = activityBefore.location
                activity.id = activityBefore.id
                activity.timeWindow.startTime = activityAssignmentBefore.endOfServiceTime
                activity.timeWindow.endTime = activityAssignmentAfter.startOfServiceTime - time[activity.id, activityAssignmentAfter.activity.id]
                activityAssignment.startOfServiceTime = activity.timeWindow.startTime
                activityAssignment.endOfServiceTime = activity.timeWindow.endTime
            end
        end

        # Update KPIs 
        schedule.totalDistance = getTotalDistanceRoute(schedule.route,distance)
        schedule.totalIdleTime = getTotalIdleTimeRoute(schedule.route) 
        schedule.totalCost = getTotalCostRouteOnline(time,schedule.route,Dict{Int, Dict{String, Int}}(),serviceTimes)
        solution.totalDistance += schedule.totalDistance
        solution.totalIdleTime += schedule.totalIdleTime
        solution.totalCost += schedule.totalCost
    end

    


end


#-------
# Determine offline solution with anticipation
#-------
function offlineSolutionWithAnticipation(requestFile::String,vehiclesFile::String,parametersFile::String,alnsParameters::String,scenarioName::String,nExpected::Int)

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    #Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    # Variables to determine best solution
    bestAverageObj = typemax(Float64)
    bestSolution::Union{Nothing, Solution} = nothing
    bestRequestBank::Union{Nothing, Vector{Int}} = nothing
    bestNotServicedExpectedRequests = typemax(Int)
    results = DataFrame(runId = String[],
                        averageObj = Float64[],
                        averageNotServicedExpectedRequests = Float64[],
                        nInitialNotServicedFixedRequests = Int[],
                        nInitialNotServicedExpectedRequests = Int[])


    for i in 1:10

        # Make scenario
        scenario = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName)
        time = scenario.time
        distance = scenario.distance
        serviceTimes = scenario.serviceTimes
        requests = scenario.requests
        taxiParameter = scenario.taxiParameter
        nFixed = scenario.nFixed
        taxiParameterExpected = scenario.taxiParameterExpected

        # Get solution
        initialSolution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
        originalSolution, originalRequestBank,_,_, _,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank)

        # Determine number of serviced requests
        nNotServicedFixedRequests = sum(originalRequestBank .<= nFixed)
        nNotServicedExpectedRequests = sum(originalRequestBank .> nFixed)
        nServicedFixedRequests = nFixed - nNotServicedFixedRequests
        nServicedExpectedRequests = nExpected - nNotServicedExpectedRequests

        # Remove expected requests from solution
        removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,originalSolution,nExpected,nFixed,nNotServicedExpectedRequests,originalRequestBank,taxiParameter,taxiParameterExpected)

        # TODO remove when stable
        state = State(originalSolution,Request(),0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=nExpected)
        if !feasible
            return originalSolution, requestBank, results, scenario, Scenario(), false, msg
        end

        # Determine Obj
        averageObj = 0.0
        averageNotServicedExpectedRequests = 0.0
        for j in 1:10

            # Get solution
            solution = copySolution(originalSolution)
            
            # Generate new scenario
            scenario2 = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName)

            # Insert expected requests randomly into solution using regret insertion
            expectedRequestsIds = collect(nFixed+1:nFixed+nExpected)
            solution.nTaxiExpected = nExpected
            solution.totalCost += nExpected * taxiParameterExpected
            solution.nTaxi = 0
            stateALNS = ALNSState(solution,1,1,expectedRequestsIds)
            regretInsertion(stateALNS,scenario2)

            # TODO remove when stable
            state = State(solution,Request(),nNotServicedFixedRequests)
            feasible, msg = checkSolutionFeasibilityOnline(scenario2,state)
            if !feasible
                return solution, requestBank, results, scenario, scenario2, feasible, msg
            end

            # Calculate Obj
            averageObj += solution.totalCost + originalSolution.nTaxi * taxiParameter 
            averageNotServicedExpectedRequests += length(stateALNS.requestBank)
        end
        averageObj /= 10
        averageNotServicedExpectedRequests /= 10

        # Check if solution is better than best solution
        if averageObj < bestAverageObj 
            bestAverageObj = averageObj
            bestNotServicedExpectedRequests = averageNotServicedExpectedRequests
            bestSolution = copySolution(originalSolution)
            bestRequestBank = copy(originalRequestBank)
        end
        

        # Save results
        push!(results, (runId = "Run $i", averageObj = averageObj, averageNotServicedExpectedRequests = averageNotServicedExpectedRequests, 
                        nInitialNotServicedFixedRequests = nNotServicedFixedRequests, nInitialNotServicedExpectedRequests = nNotServicedExpectedRequests))
    end

    return bestSolution, bestRequestBank, results, Scenario(), Scenario(), true, ""

end


