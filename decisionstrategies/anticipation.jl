using offlinesolution
using domain
using utils
using DataFrames
using CSV
using alns
using Test
using TimerOutputs
using JSON


#==
# Constants for data generation 
==#
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global MAX_DELAY = 45 

#==
# Grid constants 
==#
global MAX_LAT = 60.721
global MIN_LAT = 59.165
global MAX_LONG = 12.458
global MIN_LONG = 9.948


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


function readInstanceAnticipation(requestFile::String,nNewExpected::Int, vehicleFile::String, parametersFile::String,scenarioName=""::String,gridFile::String = "")

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
    if gridFile == ""
        useGrid = false
    else
        useGrid = true
        if !isfile(gridFile)
            error("Error: Grid file $gridFile does not exist.")
        end
    end
   

    # Read request, vehicle and parameters dataframes from input
    requestsDf = CSV.read(requestFile, DataFrame)
    vehiclesDf = CSV.read(vehicleFile, DataFrame)
    parametersDf = CSV.read(parametersFile, DataFrame)
    nRequests = nrow(requestsDf)

    # Read grid and depot locations 
    grid = nothing
    if useGrid
        gridJSON = JSON.parsefile(gridFile) 
        maxLat = gridJSON["max_latitude"]
        minLat = gridJSON["min_latitude"]
        maxLong = gridJSON["max_longitude"]
        minLong = gridJSON["min_longitude"]
        nRows = gridJSON["num_rows"]
        nCols = gridJSON["num_columns"]
        latStep = (maxLat - minLat) / nRows
        longStep = (maxLong - minLong) / nCols
 
        grid = Grid(maxLat,minLat,maxLong,minLong,nRows,nCols,latStep,longStep)
        depotLocationsGrid = findDepotLocations(grid,nRequests)
        depotCoordinates = [(l.lat,l.long) for l in values(depotLocationsGrid)]
        nDepots = length(depotLocationsGrid)
    end
    
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
    
    # Get vehicles 
    vehicles,depots, depotLocations = readVehicles(vehiclesDf,nRequests+nNewExpected,grid,useGrid)
    if !useGrid 
        depotCoordinates = collect(keys(depotLocations))
        nDepots = length(depotCoordinates)
    end

    # Generate expected requests
    newExpectedRequestsDf = createExpectedRequests(nNewExpected,nRequests)

    # Read time and distance matrices from input or initialize empty matrices
    distance, time = getDistanceAndTimeMatrixFromDataFrame(requestsDf,newExpectedRequestsDf,depotCoordinates)

    # Get requests 
    requests = readRequests(requestsDf,nRequests+nNewExpected,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time)
    expectedRequests = readRequests(newExpectedRequestsDf,nNewExpected,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time,extraN=nRequests)
    allRequests = vcat(requests, expectedRequests)

    # Split into offline and online requests
    onlineRequests, offlineRequests = splitRequests(allRequests)

    if useGrid 
        return Scenario(scenarioName,allRequests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,distance,time,nDepots,depots,taxiParameter,nNewExpected,taxiParameterExpected,nRequests,grid,depotLocationsGrid)
    else 
        return Scenario(scenarioName,allRequests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,distance,time,nDepots,depots,taxiParameter,nNewExpected,taxiParameterExpected,nRequests)
    end

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

#------ 
# Update ids in route
#------
function updateIds!(solution::Solution,nFixed::Int,nExpected::Int)

    for schedule in solution.vehicleSchedules
        # Update depotId
        schedule.vehicle.depotId -= 2*nExpected
        schedule.vehicle.depotLocation.name = String("Depot $(schedule.vehicle.depotId)")

        # Update ids in route
        for activityAssignment in schedule.route

            # Update vehicle
            activityAssignment.vehicle.depotId = schedule.vehicle.depotId
            activityAssignment.vehicle.depotLocation.name = schedule.vehicle.depotLocation.name

            # If activity is a depot, update id
            if activityAssignment.activity.activityType == DEPOT
                activityAssignment.activity.id -= 2*nExpected
                activityAssignment.activity.location.name = String("Depot $(activityAssignment.activity.id)")
            elseif activityAssignment.activity.activityType == DROPOFF
                activityAssignment.activity.id -= nExpected
            elseif activityAssignment.activity.activityType == WAITING && activityAssignment.activity.id > nFixed && activityAssignment.activity.id <= 2*nFixed + 2*nExpected
                activityAssignment.activity.id -= nExpected
            elseif activityAssignment.activity.activityType == WAITING && activityAssignment.activity.id > nFixed && activityAssignment.activity.id > 2*nFixed + 2*nExpected
                activityAssignment.activity.id -= 2*nExpected
                activityAssignment.activity.location.name = String("Depot $(activityAssignment.activity.id)")
            end

        end
    end

end

#-------
# Determine offline solution with anticipation
#-------
function offlineSolutionWithAnticipation(originalScenario::Scenario,repairMethods::Vector{GenericMethod},destroyMethods::Vector{GenericMethod},requestFile::String,vehiclesFile::String,parametersFile::String,alnsParameters::String,scenarioName::String,nExpected::Int,gridFile::String,nOfflineOriginal::Int;displayPlots::Bool=false)

    # Variables to determine best solution
    bestRunId = -1
    bestAverageObj = typemax(Float64)
    bestSolution::Union{Nothing, Solution} = nothing
    bestRequestBank::Union{Nothing, Vector{Int}} = nothing
    bestNotServicedExpectedRequests = typemax(Int)
    results = DataFrame(runId = String[],
                        averageObj = Float64[],
                        averageNotServicedExpectedRequests = Float64[],
                        nInitialNotServicedFixedRequests = Int[],
                        nInitialNotServicedExpectedRequests = Int[])
    nRequests = 0

    # TODO: change to 10
    for i in 1:10 # TODO: change to 10
        println("==========================================")
        println("Run: ", i)

        # Make scenario
        scenario = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile)
        time = scenario.time
        distance = scenario.distance
        serviceTimes = scenario.serviceTimes
        requests = scenario.requests
        taxiParameter = scenario.taxiParameter
        nFixed = scenario.nFixed
        taxiParameterExpected = scenario.taxiParameterExpected
        nRequests = length(requests)

        # Get solution
        initialSolution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
        # fixedOfflineRequests = [r for r in scenario.offlineRequests if r.id <= nFixed]
        # initialSolution, requestBank = simpleConstruction(scenario,fixedOfflineRequests)
        # println("Length of requestBank: ", length(requestBank))
        # println("scenario.requests[1:nFixed]: ",length(fixedOfflineRequests))
        # append!(requestBank,collect((nFixed+1):(nFixed+nExpected)))
        # initialSolution.nTaxiExpected = nExpected
        # initialSolution.totalCost += nExpected * taxiParameterExpected

        state = State(initialSolution,Request(),0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=0) 
        if !feasible
            #printSolution(initialSolution,printRouteHorizontal)
            throw(msg)
        end

        originalSolution, originalRequestBank,_,_, _,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank)

        display(createGantChartOfSolutionAnticipation(scenario,originalSolution,"SOLUTION AFTER ALNS, run: "*string(i),nFixed,originalRequestBank))

        # if displayPlots
        #     display(createGantChartOfSolutionOnline(originalSolution,"Initial Solution "*string(i)*" before ALNS and before removing expected requests"))
        #     #display(plotRoutes(originalSolution,scenario,requestBank,"Initial Solution "*string(i)*" before ALNS and before removing expected requests"))
        # end

        # Determine number of serviced requests
        nNotServicedFixedRequests = sum(originalRequestBank .<= nFixed)
        nNotServicedExpectedRequests = sum(originalRequestBank .> nFixed)
        nServicedFixedRequests = length(scenario.offlineRequests) - nExpected - nNotServicedFixedRequests
        nServicedExpectedRequests = nExpected - nNotServicedExpectedRequests

        println("\t Number of not serviced fixed requests: ", nNotServicedFixedRequests,"/",nOfflineOriginal)
        println("\t Number of not serviced expected requests: ", nNotServicedExpectedRequests,"/",nExpected)
        println("\t Total number offline requests: ",length(scenario.offlineRequests))
        println("\t Length of requestBank: ",length(originalRequestBank))

        # Remove expected requests from solution
        removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,originalSolution,nExpected,nFixed,nNotServicedExpectedRequests,originalRequestBank,taxiParameter,taxiParameterExpected)

        if displayPlots
            display(createGantChartOfSolutionOnline(originalSolution,"Initial Solution "*string(i)*" before ALNS and after removing expected requests"))
            #display(plotRoutes(originalSolution,scenario,originalRequestBank,"Initial Solution "*string(i)*" before ALNS and after removing expected requests"))
        end


        # TODO remove when stable
        state = State(originalSolution,Request(),0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=nExpected) 
        if !feasible
            printSolution(originalSolution,printRouteHorizontal)
            throw(msg)
        end

        # Determine Obj
        averageObj = 0.0
        averageNotServicedExpectedRequests = 0.0
        for j in 1:10 # TODO

            # Get solution
            solution = copySolution(originalSolution)
            
            # Generate new scenario
            scenario2 = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile)

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
                throw(msg)
            end

            # Calculate Obj
            averageObj += solution.totalCost + originalSolution.nTaxi * taxiParameter 
            averageNotServicedExpectedRequests += length(stateALNS.requestBank)

            println("\t Sub run: ", j)
            println("\t\t Number of not serviced fixed requests: ",  length(stateALNS.requestBank),"/",nExpected)
        end
        averageObj /= 10
        averageNotServicedExpectedRequests /= 10

        # Check if solution is better than best solution
        if averageObj < bestAverageObj 
            bestRunId = i
            bestAverageObj = averageObj
            bestNotServicedExpectedRequests = averageNotServicedExpectedRequests
            bestSolution = copySolution(originalSolution)
            bestRequestBank = copy(originalRequestBank)
        end

        # Save results
        push!(results, (runId = "Run $i", averageObj = averageObj, averageNotServicedExpectedRequests = averageNotServicedExpectedRequests, 
                        nInitialNotServicedFixedRequests = nNotServicedFixedRequests, nInitialNotServicedExpectedRequests = nNotServicedExpectedRequests))
        
                    
        
    end

    # if displayPlots
    #     display(createGantChartOfSolutionOnline(bestSolution,"Best Solution"))
    # end
    
    println("BEST RUN: ", bestRunId)

    return bestSolution, bestRequestBank, results, Scenario(), Scenario(), true, ""

end

#== 
 Test solution
==#
function testSolutionAnticipation(event::Request,originalSolution::Solution,requestFile::String,vehiclesFile::String,parametersFile::String,scenarioName::String,nExpected::Int,gridFile::String;visitedRoute::Dict{Int, Dict{String, Int}} = Dict{Int, Dict{String, Int}}())
    # Determine Obj
    averageNotServicedExpectedRequests = 0.0
    averageNotServicedExpectedRequestsRelevant = 0.0

    for j in 1:10

        # Get solution
        newSolution = copySolution(originalSolution)
        
        # Generate new scenario
        scenario2 = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile)

        # Number of expected requests in time window
        nExpectedRelevant = count(r -> r.pickUpActivity.timeWindow.startTime > event.callTime && r.id > scenario2.nFixed, scenario2.requests)
        nFixed = scenario2.nFixed
        taxiParameterExpected = scenario2.taxiParameterExpected

        # Insert expected requests randomly into solution using regret insertion
        expectedRequestsIds = collect(nFixed+1:nFixed+nExpected)
        newSolution.nTaxiExpected = nExpected
        newSolution.totalCost += nExpected * taxiParameterExpected
        newSolution.nTaxi = 0
        stateALNS = ALNSState(newSolution,1,1,expectedRequestsIds)
        regretInsertion(stateALNS,scenario2,visitedRoute=visitedRoute)

        #TODO test solution

        # Calculate Obj
        averageNotServicedExpectedRequests += length(stateALNS.requestBank)/nExpectedRelevant
        averageNotServicedExpectedRequestsRelevant += length(stateALNS.requestBank)/nExpectedRelevant
    end
    averageNotServicedExpectedRequests /= 10
    averageNotServicedExpectedRequestsRelevant /= 10

    return averageNotServicedExpectedRequests, averageNotServicedExpectedRequestsRelevant

end


#==
 Inital insertion of event
==#
function onlineInsertionAnticipation(solution::Solution, event::Request, expectedRequests::Vector{Int}, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())

    # Insert event
    state = ALNSState(Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Int}(),Vector{Int}(),solution,[event.id],solution,[event.id],Vector{Int}(),0)
    regretInsertion(state,scenario,visitedRoute=visitedRoute)

    # Insert expected requests
    newRequestBank = vcat(state.requestBank, expectedRequests)
    state = ALNSState(Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Int}(),Vector{Int}(),solution,newRequestBank,solution,newRequestBank,Vector{Int}(),0)
    regretInsertion(state,scenario,visitedRoute=visitedRoute)

    return state.requestBank

end


#==
 Run online algorithm
==#
function onlineAlgorithmAnticipation(currentState::State, requestBank::Vector{Int}, scenario::Scenario, destroyMethods::Vector{GenericMethod}, repairMethods::Vector{GenericMethod})
    insertedByALNS = false 

    # Retrieve info 
    event, currentSolution, totalNTaxi = currentState.event, copySolution(currentState.solution), currentState.totalNTaxi

    # Make scenario
    scenario2 = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile) # TODO change so only new requests in next time
    time = scenario2.time
    distance = scenario2.distance
    serviceTimes = scenario2.serviceTimes
    requests = scenario2.requests
    taxiParameter = scenario2.taxiParameter
    nFixed = scenario2.nFixed
    taxiParameterExpected = scenario2.taxiParameterExpected

    # Do intitial insertion
    expectedRequests = collect!(nFixed:(nFixed+nExpected))
    newRequestBankOnline = onlineInsertionAnticipation(currentSolution,event,expectedRequests,scenario2,visitedRoute = currentState.visitedRoute)

    # Run ALNS
    # TODO: set correct parameters for alns 
    # TODO ensure that solution is correctly only accepted if no fixed customers is in requestbank except event
    finalSolution,finalOnlineRequestBank = runALNS(scenario2, scenario2.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters_online.json",initialSolution =  currentSolution, requestBank = newRequestBankOnline, event = event, alreadyRejected =  totalNTaxi, visitedRoute = currentState.visitedRoute,stage = "Online")
    
    # TODO fix
    if length(newRequestBankOnline) == 1 && length(finalOnlineRequestBank) == 0
        insertedByALNS = true
    end
    
    # Determine number of serviced requests
    nNotServicedFixedRequests = sum(originalRequestBank .<= nFixed)
    nNotServicedExpectedRequests = sum(originalRequestBank .> nFixed)
    nServicedFixedRequests = nFixed - nNotServicedFixedRequests
    nServicedExpectedRequests = nExpected - nNotServicedExpectedRequests

    # Remove expected requests from solution
    removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,finalSolution,nExpected,nFixed,nNotServicedExpectedRequests,finalOnlineRequestBank,taxiParameter,taxiParameterExpected)

    # Update Ids
    updateIds!(finalSolution,length(scenario.requests),nExpected)


    # TODO: remove when alns is stable
    if length(finalOnlineRequestBank) > 1 || (length(finalOnlineRequestBank) == 1 && finalOnlineRequestBank[1] != event.id)
        println("ALNS: FINAL REQUEST BANK IS NOT EMPTY")
        println(finalOnlineRequestBank)
        println("Event: ",event.id)
        printSolution(finalSolution,printRouteHorizontal)
        throw("error")
    end

    append!(requestBank,finalOnlineRequestBank)

    feasible, msg = checkSolutionFeasibilityOnline(scenario,finalSolution, event, currentState.visitedRoute,totalNTaxi)

    # TODO: remove when alns is stable 
    if !feasible
        println("WRONG AFTER ALNS")
        printSolution(finalSolution,printRouteHorizontal)

        println("======================================")
        printSolution(currentSolution,printRouteHorizontal)

        throw(msg)
    end

    # Update time window for event
    updateTimeWindowsOnline!(finalSolution,scenario,searchForEvent=true,eventId = event.id)

    return finalSolution, requestBank, insertedByALNS

end



#==
 Method to measure slack in the solution 
==#
function measureSlackInSolution(solution::Solution,finalSolution::Solution, scenario::Scenario, nFixed::Int)
    time = scenario.time
    finalVehicleSchedules = finalSolution.vehicleSchedules

    # Get slack in solution
    slack = 0.0
    for schedule in solution.vehicleSchedules
        route = schedule.route

        # No slack in empty route?
        if length(route) == 2 && route[1].activity.activityType == DEPOT && route[2].activity.activityType == DEPOT
            continue
        end

        for (idx,activityAssignment) in enumerate(route)
            activity = activityAssignment.activity

            # If dummy requests 
            if activity.requestId > nFixed
                if idx == 1
                    activityBeforeDummy = finalVehicleSchedules[schedule.vehicle.id].route[end]
                else
                    activityBeforeDummy = route[idx-1]
                end
                activityAfterDummy = route[idx+1]

                totalTime = activityBeforeDummy.endOfServiceTime - activityAfterDummy.startOfServiceTime

                # Slack is the idle time we would have if we remove the dummy request
                slack += totalTime -  time[activityBeforeDummy.activity.id, activityAfterDummy.activity.id]

            # If idle time waiting (so not necesarry waiting)
            elseif activity.activityType == WAITING 
                slack += activityAssignment.endOfServiceTime - activityAssignment.startOfServiceTime
            end

        end
    end

    return slack

end