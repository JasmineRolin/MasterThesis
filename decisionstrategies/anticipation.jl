using offlinesolution
using domain
using utils
using DataFrames
using CSV
using alns
using Test
using TimerOutputs

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

    # Generate expected request DF
    for i in 1:N
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance)
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
    

    # Get vehicles 
    vehicles,depots, depotLocations = readVehicles(vehiclesDf,nRequests)
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

    # Get distance and time matrix
    scenario = Scenario(scenarioName,allRequests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,distance,time,nDepots,depots,taxiParameter)

    return scenario, nRequests, newExpectedRequestsDf

end


function removeExpectedRequestsFromSolution!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},solution::Solution,nExpected::Int,nFixed::Int,nNotServicedExpectedRequests::Int,requestBank::Vector{Int},taxiParameter::Float64;TO::TimerOutput=TimerOutput())
    
    # Determine remaining requests to remove
    requestsToRemove = Set{Int}()
    for i in nFixed+1:nFixed+nExpected
        if i in requestBank
            continue
        end
        # Add to remaining requests
        push!(requestsToRemove, i)
    end

    println("Length of requests to remove: ", length(requestsToRemove))
    println(requestsToRemove)

    # Choice of removal of activity
    remover = removeExpectedActivityFromRouteWF!
    removeRequestsFromSolution!(time,distance,serviceTimes,requests,solution,requestsToRemove,remover=remover)

    # Remove taxis for expected requests
    solution.nTaxi -= nNotServicedExpectedRequests
    solution.totalCost -= nNotServicedExpectedRequests * taxiParameter


end

function removeExpectedActivityFromRouteBasic!(time::Array{Int,2},schedule::VehicleSchedule,idx::Int)

    # Retrieve activities before and after activity to remove
    route = schedule.route
    currentActivity = route[idx]

    # How much did the route length reduce 
    routeReduction = 0

    currentActivity.activity.activityType = WAITING
    currentActivity.activity.timeWindow.startTime = currentActivity.startOfServiceTime
    currentActivity.activity.timeWindow.endTime = currentActivity.endOfServiceTime

    return routeReduction

end

function removeExpectedActivityFromRouteWF!(time::Array{Int,2}, schedule::VehicleSchedule, idx::Int)
    route = schedule.route

    # Find number of WAITING activities before idx
    nActivitiesBefore = 0
    for i in idx-1:-1:1
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

    # Extract activities before and after the activity to remove and the waiting activities
    activityAssignmentBefore = route[idxStart - 1]
    activityAssignmentAfter = route[idxEnd + 1]

    # Calculate route reduction
    routeReduction = idxEnd - idxStart

    # Remove activities (from end to start to avoid index shifting)
    for _ in idxStart:idxEnd
        deleteat!(route, idxStart)
    end

    # Insert WAITING activity
    startOfWaitingActivity = activityAssignmentBefore.endOfServiceTime
    endOfWaitingActivity = activityAssignmentAfter.startOfServiceTime -time[activityAssignmentBefore.activity.id, activityAssignmentAfter.activity.id]
    waitingActivity = Activity(activityAssignmentBefore.activity.id,-1,WAITING,activityAssignmentBefore.activity.location,TimeWindow(startOfWaitingActivity, endOfWaitingActivity))
    waitingAssignment = ActivityAssignment(waitingActivity,activityAssignmentBefore.vehicle,startOfWaitingActivity,endOfWaitingActivity)

    insert!(route, idxStart, waitingAssignment)

    return routeReduction
end

function removeExpectedActivityFromRouteWF2!(time::Array{Int,2},schedule::VehicleSchedule,idx::Int)

    # Retrieve activities before and after activity to remove
    route = schedule.route
    activityAssignmentBefore = route[idx-1]
    activityAssignmentAfter = route[idx+1]

    # How much did the route length reduce 
    routeReduction = 0

    # Remove activity 
    # If there is a waiting activity both before and after 
    if activityAssignmentBefore.activity.activityType == WAITING && activityAssignmentAfter.activity.activityType == WAITING

        # Update waiting activity 
        activityAssignemntAfterWaiting = route[idx+2]
        activityAssignmentBefore.endOfServiceTime = activityAssignemntAfterWaiting.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignemntAfterWaiting.activity.id]
        activityAssignmentBefore.activity.timeWindow.endTime = activityAssignmentBefore.endOfServiceTime

        # Delete activity
        deleteat!(route,idx) # Delete activity 
        deleteat!(route,idx) # Delete waiting activity

        routeReduction = 2

    # Extend waiting activity before activity to remove
    elseif activityAssignmentBefore.activity.activityType == WAITING
        # Update waiting activity 
        activityAssignmentBefore.endOfServiceTime = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentBefore.activity.timeWindow.endTime = activityAssignmentBefore.endOfServiceTime

        # Delete activity
        deleteat!(route,idx)

        routeReduction = 1

    # Extend waiting activity after activity to remove
    elseif activityAssignmentAfter.activity.activityType == WAITING
        # Update waiting activity
        activityAssignmentAfter.startOfServiceTime = activityAssignmentBefore.endOfServiceTime + time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentAfter.activity.timeWindow.startTime = activityAssignmentAfter.startOfServiceTime
        
        # Delete activity 
        deleteat!(route,idx)

        routeReduction = 1

    # Insert waiting activity before activity to remove
    else
        # Create waiting activity 
        startOfWaitingActivity = activityAssignmentBefore.endOfServiceTime
        endOfWaitingActivity = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]

        waitingActivity = Activity(activityAssignmentBefore.activity.id,-1,WAITING,activityAssignmentBefore.activity.location,TimeWindow(startOfWaitingActivity,endOfWaitingActivity))
        waitingActivityAssignment = ActivityAssignment(waitingActivity,activityAssignmentBefore.vehicle,startOfWaitingActivity,endOfWaitingActivity)
                
        # Update route 
        route[idx] = waitingActivityAssignment
    end

    return routeReduction

end


function offlineSolutionWithAnticipation(requestFile::String,vehiclesFile::String,parametersFile::String,alnsParameters::String,scenarioName::String,nExpected::Int,scenario::Scenario)

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
    bestAverageSAE = typemax(Float64)
    bestSolution::Union{Nothing, Solution} = nothing
    bestRequestBank::Union{Nothing, Vector{Int}} = nothing
    results = DataFrame(runId = String[],
                        averageSAE = Float64[],
                        nServicedFixedRequests = Int[],
                        nServicedExpectedRequests = Int[],
                        nNotServicedFixedRequests = Int[],
                        nNotServicedExpectedRequests = Int[])


    for i in 1:10
        # Make scenario
        scenario, nFixed = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName)
        time = scenario.time
        distance = scenario.distance
        serviceTimes = scenario.serviceTimes
        requests = scenario.requests
        taxiParameter = scenario.taxiParameter

        # Get solution
        initialSolution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
        originalSolution, originalRequestBank,_,_, _,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank)

        # Determine number of serviced requests
        nNotServicedFixedRequests = sum(originalRequestBank .<= nFixed)
        nNotServicedExpectedRequests = sum(originalRequestBank .> nFixed)
        nServicedFixedRequests = nFixed - nNotServicedFixedRequests
        nServicedExpectedRequests = nExpected - nNotServicedExpectedRequests

        # Remove expected requests from solution
        removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,originalSolution,nExpected,nFixed,nNotServicedExpectedRequests,originalRequestBank,scenario.taxiParameter)

        # TODO remove when stable
        state = State(originalSolution,Request(),0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=nExpected)
        if !feasible
            printSolution(originalSolution,printRouteHorizontal)
            println("Solution is not feasible")
            throw(msg)
        end

        # Determine SAE
        averageSAE = 0.0
        for _ in 1:10
            # Get solution
            solution = copySolution(originalSolution)
            
            # Generate new scenario
            scenario2, nFixed = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName)

            # Insert expected requests randomly into solution using regret insertion
            expectedRequestsIds = collect(nFixed+1:nFixed+nExpected)
            solution.nTaxi = nExpected
            solution.totalCost += nExpected * scenario.taxiParameter
            stateALNS = ALNSState(solution,1,1,expectedRequestsIds)
            regretInsertion(stateALNS,scenario2)

            # TODO remove when stable
            state = State(solution,Request(),nNotServicedFixedRequests)
            feasible, msg = checkSolutionFeasibilityOnline(scenario2,state)
            if !feasible
                printSolution(solution,printRouteHorizontal)
                println("Solution is not feasible")
                println(msg)
                return solution, requestBank, results, scenario, scenario2, feasible, msg
            end

            # Calculate SAE
            averageSAE += solution.totalCost + originalSolution.nTaxi * taxiParameter
        end
        averageSAE /= 10

        # Check if solution is better than best solution
        if averageSAE < bestAverageSAE 
            bestAverageSAE = averageSAE
            bestSolution = copySolution(originalSolution)
            bestRequestBank = copy(originalRequestBank)
        end
        

        # Save results
        push!(results, (runId = "Run $i", averageSAE = averageSAE, nServicedFixedRequests = nServicedFixedRequests, nServicedExpectedRequests = nServicedExpectedRequests, nNotServicedFixedRequests = nNotServicedFixedRequests, nNotServicedExpectedRequests = nNotServicedExpectedRequests))
    end

    return bestSolution, bestRequestBank, results, scenario, scenario2, feasible, msg

end


