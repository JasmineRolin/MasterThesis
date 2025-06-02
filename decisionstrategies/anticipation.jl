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

    _,probabilities_offline,probabilities_online,probabilities_location,_,x_range,y_range,probabilities_distance,_,distance_range,_,_,_,_= load_simulation_data("Data/Simulation data/")
    time_range = collect(range(6*60,23*60))
    max_lat, min_lat, max_long, min_long = MAX_LAT, MIN_LAT, MAX_LONG, MIN_LONG

    # Generate expected request DF
    for i in 1:N
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance,max_lat, min_lat, max_long, min_long)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]

        # Determine type of request
        if rand() <= 1 #TODO change 
            requestType = 0  # pick-up request

            sampled_indices = sample(1:length(probabilities_online), Weights(probabilities_online), 1)
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

            sampled_indices = sample(1:nTimes, Weights(probabilities_online[indices]), 1)
            sampledTimeDrop = time_range[indices][sampled_indices]
            requestTime = ceil(sampledTimeDrop[1])
        end

        # Append results for the request
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


function readInstanceAnticipation(requestFile::String,nNewExpected::Int, vehicleFile::String, parametersFile::String,scenarioName=""::String,gridFile::String = "";useAnticipationOnlineRequests::Bool=false)

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
    if useAnticipationOnlineRequests
        newExpectedRequestsDf = makeAnticipationOnlineRequests(requestsDf, nRequests)
    else
        newExpectedRequestsDf = createExpectedRequests(nNewExpected,nRequests)
    end

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


function makeAnticipationOnlineRequests(requestDF::DataFrame, nRequests::Int)

    # Filter requests where call_time > 0
    filteredDF = requestDF[requestDF.call_time .> 0, :]

    # Create modified copy with updated values
    newIds = collect(1:nrow(filteredDF)) #.+ nRequests
    newDF = DataFrame(
        id = newIds,
        pickup_latitude = filteredDF.pickup_latitude,
        pickup_longitude = filteredDF.pickup_longitude,
        dropoff_latitude = filteredDF.dropoff_latitude,
        dropoff_longitude = filteredDF.dropoff_longitude,
        request_type = filteredDF.request_type,
        request_time = filteredDF.request_time,
        mobility_type = filteredDF.mobility_type,
        call_time = fill(0, nrow(filteredDF)),  # reset call_time
        direct_drive_time = filteredDF.direct_drive_time,
    )

    return newDF
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


#==
 Create offline solution with anticipation
==#
function offlineSolutionWithAnticipation(repairMethods::Vector{GenericMethod},destroyMethods::Vector{GenericMethod},requestFile::String,vehiclesFile::String,parametersFile::String,alnsParameters::String,scenarioName::String,nExpected::Int,gridFile::String,nOfflineOriginal::Int;displayPlots::Bool=false,keepExpectedRequests::Bool=false,useAnticipationOnlineRequests::Bool=false)

    # Variables to determine best solution
    bestRunId = -1
    bestAverageObj = typemax(Float64)
    bestSolution::Union{Nothing, Solution} = nothing
    bestRequestBank::Union{Nothing, Vector{Int}} = nothing
    bestScenario::Union{Nothing, Scenario} = nothing
    bestNotServicedExpectedRequests = typemax(Int)
    bestALNSIterations = typemax(Int)
    results = DataFrame(runId = String[],
                        averageObj = Float64[],
                        averageNotServicedExpectedRequests = Float64[],
                        nInitialNotServicedFixedRequests = Int[],
                        nInitialNotServicedExpectedRequests = Int[], ALNSIterations = Int[])
    nRequests = 0

    # Create different scenarios and solve problem with known offline requests and predicted online requests 
    for i in 1:10 #TODO change
        println("==========================================")
        println("Run: ", i)

        # Make scenario
        if useAnticipationOnlineRequests
            scenario = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile,useAnticipationOnlineRequests=true)
        else 

            scenario = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile)
        end
        time = scenario.time
        distance = scenario.distance
        serviceTimes = scenario.serviceTimes
        requests = scenario.requests
        taxiParameter = scenario.taxiParameter
        nFixed = scenario.nFixed
        taxiParameterExpected = scenario.taxiParameterExpected
        nRequests = length(requests)

        # Get solution
        println(scenario.offlineRequests)
        initialSolution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

        # TODO: remove 
        state = State(initialSolution,Request(),0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=0) 
        if !feasible
            #printSolution(initialSolution,printRouteHorizontal)
            throw(msg)
           end

        originalSolution, originalRequestBank,_,_, _,_,_,ALNSIterations = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank)
        
        # Save solution with requests
        if keepExpectedRequests
            originalSolutionWithAllRequests = copySolution(originalSolution)
            originalRequestBankWithAllRequests = copy(originalRequestBank)
        end

     

        if displayPlots
            #display(createGantChartOfSolutionAnticipation(scenario,originalSolution,"SOLUTION AFTER ALNS, run: "*string(i),nFixed,originalRequestBankWithAllRequests))
            display(createGantChartOfSolutionOnline(originalSolution,"Initial Solution "*string(i)*" before ALNS and before removing expected requests",nFixed = scenario.nFixed))
            #display(plotRoutes(originalSolution,scenario,requestBank,"Initial Solution "*string(i)*" before ALNS and before removing expected requests"))
        end

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
            display(createGantChartOfSolutionOnline(originalSolution,"Initial Solution "*string(i)*" before ALNS and after removing expected requests",nFixed = scenario.nFixed))
            #display(plotRoutes(originalSolution,scenario,originalRequestBank,"Initial Solution "*string(i)*" before ALNS and after removing expected requests"))
        end


        # TODO remove when stable
        state = State(originalSolution,Request(),0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=nExpected)
        if !feasible
            throw(msg)
        end

        # Insert new sampled predicted requests into solution
        averageObj = 0.0
        averageNotServicedExpectedRequests = 0.0
        for j in 1:10

            # Get solution
            solution = copySolution(originalSolution)
            
            # Generate new scenario
            if useAnticipationOnlineRequests
                scenario2 = scenario
            else
                scenario2 = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName,gridFile)
            end

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
            println("\t\t Number of not serviced expected requests: ",  length(stateALNS.requestBank),"/",nExpected)
        end

        averageObj /= 10
        averageNotServicedExpectedRequests /= 10

        # Check if solution is better than best solution
        if averageObj < bestAverageObj 
            bestAverageObj = averageObj
            bestNotServicedExpectedRequests = averageNotServicedExpectedRequests
            bestALNSIterations = ALNSIterations
            if keepExpectedRequests
                bestSolution = originalSolutionWithAllRequests
                bestRequestBank = originalRequestBankWithAllRequests
                bestScenario = copyScenario(scenario)
            else
                bestSolution = copySolution(originalSolution)
                bestRequestBank = copy(originalRequestBank)
            end
        end

        # Save results
        push!(results, (runId = "Run $i", averageObj = averageObj, averageNotServicedExpectedRequests = averageNotServicedExpectedRequests, 
                        nInitialNotServicedFixedRequests = nNotServicedFixedRequests, nInitialNotServicedExpectedRequests = nNotServicedExpectedRequests, ALNSIterations = ALNSIterations))
        
        println("BEST RUN: ", bestRunId)

                        
    end

    if keepExpectedRequests
        expectedRequests = bestScenario.requests[bestScenario.nFixed+1:end]
        onlineRequests = bestScenario.onlineRequests
        matches = match_similar_requests(expectedRequests, onlineRequests)
        p = plot_matched_request_gantts(expectedRequests,onlineRequests, matches)
        display(p)
    end

    if keepExpectedRequests
        return bestSolution, bestRequestBank, results, bestScenario, Scenario(), true, "", bestALNSIterations
    else
        return bestSolution, bestRequestBank, results, Scenario(), Scenario(), true, "", bestALNSIterations
    end
    

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


function match_similar_requests(reqs1::Vector{Request}, reqs2::Vector{Request};
                                max_time_diff=15,
                                max_dist_km=2.0)

    matches = Tuple{Int, Int, Float64}[]
    used = Set{Int}()

    for r1 in reqs1
        best_score = Inf
        best_match = nothing
        best_index = 0

        for (i, r2) in enumerate(reqs2)
            if i in used
                continue
            end

            score = request_similarity(r1, r2; max_time_diff=max_time_diff, max_dist_km=max_dist_km)
            if score < best_score
                best_score = score
                best_match = r2
                best_index = i
            end
        end

        if best_match !== nothing && best_score < Inf
            push!(matches, (r1.id, best_match.id, best_score))
            push!(used, best_index)
        end
    end

    return matches
end


function request_similarity(r1::Request, r2::Request;
    max_time_diff=30,   # max time difference in minutes
    max_dist_km=2.0,    # max distance in kilometers
    time_weight=1.0,
    space_weight=1.0)

    # Pickup time window start difference
    pickup_time_diff = abs(r1.pickUpActivity.timeWindow.startTime - r2.pickUpActivity.timeWindow.startTime)
    dropoff_time_diff = abs(r1.dropOffActivity.timeWindow.startTime - r2.dropOffActivity.timeWindow.startTime)

    # Skip if time difference too large
    if pickup_time_diff > max_time_diff || dropoff_time_diff > max_time_diff
        return Inf
    end

    # Pickup spatial distance
    pickup_dist = haversine_distance(r1.pickUpActivity.location.lat, r1.pickUpActivity.location.long,
                r2.pickUpActivity.location.lat, r2.pickUpActivity.location.long)[1] / 1000

    # Dropoff spatial distance
    dropoff_dist = haversine_distance(r1.dropOffActivity.location.lat, r1.dropOffActivity.location.long,
                r2.dropOffActivity.location.lat, r2.dropOffActivity.location.long)[1] / 1000

    # Skip if spatial distance too large
    if pickup_dist > max_dist_km || dropoff_dist > max_dist_km
        return Inf
    end

    return time_weight * (pickup_time_diff + dropoff_time_diff) + space_weight * (pickup_dist + dropoff_dist)
end

function plot_matched_request_gantts(reqs1::Vector{Request}, reqs2::Vector{Request}, matches::Vector{Tuple{Int, Int, Float64}})

    matched_ids1 = Set(map(x -> x[1], matches))
    matched_ids2 = Set(map(x -> x[2], matches))

    # First Gantt chart (left)
    p1 = plot(title="Expected Requests", size=(1000, 600), xlabel="Time (min after midnight)", ylabel="Requests", legend=false)
    y1_labels, y1_ticks = String[], Int[]
    for (i, req) in enumerate(reqs1)
        y = length(reqs1) - i + 1
        color_pickup = in(req.id, matched_ids1) ? :green : :red
        color_dropoff = in(req.id, matched_ids1) ? :lightgreen : :orange
    
        pickup_tw = req.pickUpActivity.timeWindow
        dropoff_tw = req.dropOffActivity.timeWindow
    
        plot!(p1, [pickup_tw.startTime, pickup_tw.endTime], [y, y], linewidth=6, color=color_pickup, label=false)
        plot!(p1, [dropoff_tw.startTime, dropoff_tw.endTime], [y, y], linewidth=6, color=color_dropoff, label=false)
    
        push!(y1_labels, "Req $(req.id)")
        push!(y1_ticks, y)
    end
    
    yticks!(p1, y1_ticks, y1_labels)

    # Second Gantt chart (right)
    p2 = plot(title="Online Requests", size=(1000, 600), xlabel="Time (min after midnight)", ylabel="Requests", legend=false)
    y2_labels, y2_ticks = String[], Int[]
    for (i, req) in enumerate(reqs2)
        y = length(reqs1) - i + 1
        color_pickup = in(req.id, matched_ids2) ? :green : :red
        color_dropoff = in(req.id, matched_ids2) ? :lightgreen : :orange
    
        pickup_tw = req.pickUpActivity.timeWindow
        dropoff_tw = req.dropOffActivity.timeWindow
    
        plot!(p2, [pickup_tw.startTime, pickup_tw.endTime], [y, y], linewidth=6, color=color_pickup, label=false)
        plot!(p2, [dropoff_tw.startTime, dropoff_tw.endTime], [y, y], linewidth=6, color=color_dropoff, label=false)
    
        push!(y2_labels, "Req $(req.id)")
        push!(y2_ticks, y)
    end
    
    yticks!(p2, y2_ticks, y2_labels)

    # Combine and return
    return plot(p1, p2, layout=(1, 2))
end
