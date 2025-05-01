
module SimulationFramework

using utils
using domain
using offlinesolution
using onlinesolution
using alns
using waitingstrategies

export simulateScenario

# ------
# Function to update current state if entire route has been served and vehicle is not available anymore
# ------
function updateCurrentScheduleNotAvailableAnymore!(currentState::State,schedule::VehicleSchedule,vehicle::Int)

    # Update visited route
    for i in 1:length(schedule.route)
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end
   
    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update schedule with only end  depot for unavailable vehicle 
    currentSchedule.route = [schedule.route[end]]
    currentSchedule.activeTimeWindow.startTime = schedule.route[end].endOfServiceTime
    currentSchedule.activeTimeWindow.endTime = schedule.route[end].endOfServiceTime

    # Update current state
    currentState.solution.totalDistance -= currentSchedule.totalDistance
    currentState.solution.totalCost -= currentSchedule.totalCost
    currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime
    currentState.solution.totalRideTime -= currentSchedule.totalTime

    # Update KPIs
    currentSchedule.totalDistance = 0.0
    currentSchedule.totalCost = 0.0
    currentSchedule.totalIdleTime = 0
    currentSchedule.totalTime = 0
    currentSchedule.numberOfWalking = [0] 

    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1 

    return idx, currentSchedule.activeTimeWindow.startTime
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function updateCurrentScheduleRouteCompleted!(currentState::State,schedule::VehicleSchedule,vehicle::Int)

     # Update visited route
     for i in 1:length(schedule.route)
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end

   
    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update KPIs of current state pre  
    currentState.solution.totalDistance -= currentSchedule.totalDistance
    currentState.solution.totalRideTime -= currentSchedule.totalTime
    currentState.solution.totalCost -= currentSchedule.totalCost
    currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime


    arrivalAtDepot = schedule.route[end].startOfServiceTime
    endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime

    # Find waiting location

    # Create waiting activity to replace depot activity
    waitingActivityCompletedRoute = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), schedule.vehicle,arrivalAtDepot,endOfAvailableTimeWindow)

    # Update schedule with only  depots for  vehicle 
    currentSchedule.route = [waitingActivityCompletedRoute,currentSchedule.route[end]]
    currentSchedule.route[end].activity.timeWindow = TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)
    currentSchedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
    currentSchedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
    currentSchedule.activeTimeWindow.startTime = arrivalAtDepot
    currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow

    # Update KPIs
    currentSchedule.totalDistance = 0.0
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = 0.0
    currentSchedule.totalIdleTime = endOfAvailableTimeWindow - arrivalAtDepot
    currentSchedule.numberOfWalking = [0,0]

    # Update current state pro
    currentState.solution.totalDistance += currentSchedule.totalDistance
    currentState.solution.totalRideTime += currentSchedule.totalTime
    currentState.solution.totalCost += currentSchedule.totalCost
    currentState.solution.totalIdleTime += currentSchedule.totalIdleTime


    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1

    return idx, arrivalAtDepot
end

# ------
# Function to update current state if vehicle is not available yet or has not started service yet
# ------
function updateCurrentScheduleNotAvailableYet(schedule::VehicleSchedule,currentState::State,vehicle::Int)
    # update current schedule 
    currentState.solution.vehicleSchedules[vehicle] = schedule

    return 0, 0
end


# ------
# Function to update current state if vehicle has not been assigned yet
# ------
function updateCurrentScheduleNoAssignement!(vehicle::Int,currentTime::Int,currentState::State)
    # Retrieve empty schedule and update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update active time window 
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.activeTimeWindow.startTime = currentTime

    # Update depots (start and end)
    currentSchedule.route[1].startOfServiceTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime

    # index to split route into current and completed route
    idx = 0

    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle has visited some customers 
# ------
function updateCurrentScheduleAtSplit!(scenario::Scenario,schedule::VehicleSchedule,vehicle::Int,currentState::State,idx::Int)
    
    # Update visited route
    for i in 1:idx
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end

    # Retrieve empty schedule to update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update route 
    currentSchedule.route = schedule.route[idx+1:end]

    # Update active time window
    currentSchedule.activeTimeWindow.startTime = schedule.route[idx+1].startOfServiceTime 
    currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

    # Update current state pre
    currentState.solution.totalDistance -= currentSchedule.totalDistance
    currentState.solution.totalRideTime -= currentSchedule.totalTime
    currentState.solution.totalCost -= currentSchedule.totalCost
    currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime

    # Update KPIs
    currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = getTotalCostRouteOnline(scenario.time,currentSchedule.route,currentState.visitedRoute,scenario.serviceTimes)
    currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
    currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]

    # Update current state pro
    currentState.solution.totalDistance += currentSchedule.totalDistance
    currentState.solution.totalRideTime += currentSchedule.totalTime
    currentState.solution.totalCost += currentSchedule.totalCost
    currentState.solution.totalIdleTime += currentSchedule.totalIdleTime

    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle is still available but all customers are still being serviced
# ------
function updateCurrentScheduleAvailableKeepEntireRoute(schedule::VehicleSchedule,currentState::State,vehicle::Int)
    # Update current schedule 
    currentState.solution.vehicleSchedules[vehicle] = schedule

    return 0, 0
    
end


# ------
# Function to update waiting activity in route 
# ------
# Assuming waiting activity is the last activity in the route before depot 
function updateLastWaitingActivityInRoute!(time::Array{Int,2},distance::Array{Float64,2},currentSolution::Solution,schedule::VehicleSchedule,currentSchedule::VehicleSchedule,waitingIdx::Int,waitingLocationId::Int,location::Location)
    
    # Update KPIs 
    currentSolution.totalIdleTime -= currentSchedule.totalIdleTime
    currentSolution.totalRideTime -= currentSchedule.totalTime
    currentSolution.totalDistance -= currentSchedule.totalDistance
    currentSchedule.totalIdleTime = 0
    
    waitingActivity = currentSchedule.route[waitingIdx]
    waitingActivity.activity.location = location
    waitingActivity.activity.id = waitingLocationId

    # Find arrival at waiting node 
    previousActivity = schedule.route[end-1]
    depotActivity = currentSchedule.route[end]
    endOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.endTime

    timePreviousNode = time[previousActivity.activity.id,waitingLocationId]
    timeDepot = time[waitingLocationId,depotActivity.activity.id]
    arrivalAtWaiting = schedule.route[end-1].endOfServiceTime + timePreviousNode

    waitingActivity.startOfServiceTime = arrivalAtWaiting
    waitingActivity.endOfServiceTime = currentSchedule.vehicle.availableTimeWindow.endTime - timeDepot
    waitingActivity.activity.timeWindow = TimeWindow(waitingActivity.startOfServiceTime,waitingActivity.endOfServiceTime)

    # Update depot 
    depotActivity.startOfServiceTime = endOfAvailableTimeWindow
    depotActivity.endOfServiceTime = endOfAvailableTimeWindow

    # Update active time window
    currentSchedule.activeTimeWindow.startTime = arrivalAtWaiting
    currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow

    # Update KPIs
    currentSchedule.totalIdleTime = waitingActivity.endOfServiceTime - arrivalAtWaiting
    currentSchedule.totalDistance = distance[waitingLocationId,depotActivity.activity.id]
    currentSchedule.totalTime = endOfAvailableTimeWindow - arrivalAtWaiting

    # Update current state pro
    currentSolution.totalDistance += currentSchedule.totalDistance
    currentSolution.totalRideTime += currentSchedule.totalTime
    currentSolution.totalIdleTime += currentSchedule.totalIdleTime

    return arrivalAtWaiting
end

function relocateWaitingActivityBeforeDepot!(time::Array{Int,2},distance::Array{Float64,2},nRequests::Int,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},vehicleBalance::Array{Int,3},currentSolution::Solution,schedule::VehicleSchedule,currentSchedule::VehicleSchedule,splitTime::Int)
    vehicle = schedule.vehicle

    # Update waiting locations for vehicles that have completed their route but are still available 
    # TODO: add keep track of active vehicles here 
    # Determine time 
    waitingIdx = length(currentSchedule.route) - 1

    # TODO: hvilken tid skal det være ? 
    relocationTime = currentSchedule.route[waitingIdx].startOfServiceTime

    # Determine hour 
    hour = ceil(Int,relocationTime/60) + 1

    # Find waiting location
    # TODO: skal det være solution eller currentState
    waitingLocationId,waitingLocation,gridCell = determineWaitingLocation(depotLocations,grid,nRequests,vehicleBalance,hour)

    # Is there time to relocate vehicle 
    activityBeforeWaiting = schedule.route[end-1]
    if activityBeforeWaiting.endOfServiceTime + time[activityBeforeWaiting.activity.id,waitingLocationId] + time[waitingLocationId,vehicle.depotId] <= vehicle.availableTimeWindow.endTime
        # Update waiting activity 
        splitTime = updateLastWaitingActivityInRoute!(time,distance,currentSolution,schedule,currentSchedule,waitingIdx,waitingLocationId,waitingLocation) 
        
        # Update vehicle balance
        # TODO: skal det opdateres sådan?
        gridCellDepot = determineGridCell(vehicle.depotLocation,grid)
        vehicleBalance[hour,gridCellDepot[1],gridCellDepot[2]] -= 1
        vehicleBalance[hour,gridCell[1],gridCell[2]] += 1

        println("Relocating vehicle ",vehicle.id," to waiting location ",waitingLocationId," from depot ",vehicle.depotId, " in hour ",hour)
    end

    return splitTime
end


# ------
# Function to update final solution for given vehicle 
# ------
function updateFinalSolution!(scenario::Scenario,finalSolution::Solution,solution::Solution,vehicle::Int,idx::Int,splitTime::Int,visitedRoute::Dict{Int,Dict{String,Int}})
    # Return if no completed route 
    if idx == 0
        return
    end

    # Set start time of time window if necesarry
    if length(finalSolution.vehicleSchedules[vehicle].route) == 0
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow.startTime = solution.vehicleSchedules[vehicle].activeTimeWindow.startTime
    end

    # Retrieve completed route 
    newCompletedRoute =  solution.vehicleSchedules[vehicle].route[1:idx]
    append!(finalSolution.vehicleSchedules[vehicle].route, newCompletedRoute)
   
    # Update active time window 
    finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = splitTime
   
    # Update KPIs of route and solution 
    totalTimeOfNewCompletedRoute = splitTime - newCompletedRoute[1].startOfServiceTime
    newTotalCost =  getTotalCostRouteOnline(scenario.time,newCompletedRoute,visitedRoute,scenario.serviceTimes) 
    totalIdleTime = getTotalIdleTimeRoute(newCompletedRoute)

    endIndex = (idx == length(solution.vehicleSchedules[vehicle].route)) ? idx : idx + 1
    newTotalDistance = getTotalDistanceRoute(solution.vehicleSchedules[vehicle].route[1:endIndex],scenario)

    finalSolution.vehicleSchedules[vehicle].totalTime += totalTimeOfNewCompletedRoute #?
    finalSolution.vehicleSchedules[vehicle].totalDistance += newTotalDistance
    finalSolution.vehicleSchedules[vehicle].totalCost += newTotalCost 
    finalSolution.vehicleSchedules[vehicle].totalIdleTime += totalIdleTime
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])

    finalSolution.totalRideTime += totalTimeOfNewCompletedRoute
    finalSolution.totalDistance += newTotalDistance
    finalSolution.totalCost += newTotalCost 
    finalSolution.totalIdleTime += totalIdleTime
end


# ------
# Function to merge current State and final solution in last iteration
# ------
function mergeCurrentStateIntoFinalSolution!(finalSolution::Solution,solution::Solution,scenario::Scenario)

    finalSolution.totalRideTime = 0 # Only because no delta calculation

    # Loop through all schedules and add to final solution 
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)

        # Set start time of time window if necesarry 
        if length(finalSolution.vehicleSchedules[vehicle].route) == 0
            finalSolution.vehicleSchedules[vehicle].activeTimeWindow.startTime = schedule.activeTimeWindow.startTime
        end

        # Update route 
        finalSolution.vehicleSchedules[vehicle].route = append!(finalSolution.vehicleSchedules[vehicle].route,schedule.route)
     
        # Update active time window 
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = schedule.activeTimeWindow.endTime

        # Update KPIs of route
        newDistance = schedule.totalDistance
        newDuration = duration(finalSolution.vehicleSchedules[vehicle].activeTimeWindow) #duration(schedule.activeTimeWindow) TODO fix 
        newCost = schedule.totalCost 
        newIdleTime = schedule.totalIdleTime

        finalSolution.vehicleSchedules[vehicle].totalDistance += newDistance
        finalSolution.vehicleSchedules[vehicle].totalTime = newDuration 
        finalSolution.vehicleSchedules[vehicle].totalCost += newCost
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += newIdleTime


        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)

        # Update KPIs of solution
        finalSolution.totalRideTime += newDuration
        finalSolution.totalDistance += newDistance
        finalSolution.totalIdleTime += newIdleTime
        finalSolution.totalCost += newCost
    end

    finalSolution.nTaxi += solution.nTaxi
    finalSolution.totalCost += scenario.taxiParameter*finalSolution.nTaxi

end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,finalSolution::Solution,scenario::Scenario,visitedRoute::Dict{Int,Dict{String,Int}},grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},vehicleDemand::Array{Int,3};relocateVehicles::Bool=false)
    nRequests = length(scenario.requests)
    time = scenario.time
    distance = scenario.distance

    # Initialize current state
    currentState = State(scenario,event,visitedRoute,0)
    currentState.solution = copySolution(solution)

    # Determine current vehicle balance 
    vehicleBalance = determineVehicleBalancePrCell(grid,vehicleDemand,currentState.solution)

    # Initialize 
    idx = -1
    splitTime = -1

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)
      #  print("UPDATING SCHEDULE: ",vehicle)

        # Check if vehicle is not available yet or has not started service yet
        if schedule.vehicle.availableTimeWindow.startTime > currentTime || schedule.route[1].startOfServiceTime > currentTime
            idx, splitTime = updateCurrentScheduleNotAvailableYet(schedule,currentState,vehicle)
            #print(" - not available yet or not started service yet \n")
        # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime < currentTime 
            idx, splitTime = updateCurrentScheduleNotAvailableAnymore!(currentState,schedule,vehicle)
           # print(" - not available anymore \n")
        # We have completed the last activity and the vehicle is on-route to the depot but still available 
        elseif schedule.route[end-1].activity.activityType != DEPOT && schedule.route[end-1].endOfServiceTime < currentTime
            idx,splitTime = updateCurrentScheduleRouteCompleted!(currentState,schedule,vehicle)

            if relocateVehicles 
                splitTime = relocateWaitingActivityBeforeDepot!(time,distance,nRequests,grid,depotLocations,vehicleBalance,currentState.solution,schedule,currentState.solution.vehicleSchedules[vehicle],splitTime)
            end
        # TODO: add case to split waiting activitiy if we are relocation vehicles 

          #  print("- completed route but still available \n")
        # Check if vehicle has not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT
            idx, splitTime = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
           # print(" - no assignments \n")
        else
            # Determine index to split
            didSplit = false
            for (split,assignment) in enumerate(schedule.route)
               if assignment.endOfServiceTime < currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
                    idx, splitTime  = updateCurrentScheduleAtSplit!(scenario,schedule,vehicle,currentState,split)
                    didSplit = true
                  #  print(" - still available, split at ",split, ", \n")
                    break
                end
            end

            if didSplit == false
                idx, splitTime = updateCurrentScheduleAvailableKeepEntireRoute(schedule,currentState,vehicle)
              #  print(" - still available, keep entire route, \n")
            end
        end

        # Update final solution
        updateFinalSolution!(scenario,finalSolution,solution,vehicle,idx, splitTime,visitedRoute)
        
    end

    finalSolution.nTaxi += solution.nTaxi
    currentState.solution.nTaxi = 1 # Because of new event
    currentState.solution.totalCost += scenario.taxiParameter*currentState.solution.nTaxi
    currentState.totalNTaxi = finalSolution.nTaxi 

    return currentState, finalSolution
end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario;printResults::Bool = false,saveResults::Bool=false,displayPlots::Bool=false,outPutFileFolder::String="tests/output",saveALNSResults::Bool = false,displayALNSPlots::Bool = false,historicRequestFiles::Vector{String} = [],gamma::Float64=0.5,relocateVehicles::Bool=false)
    # Retrieve info 
    grid = scenario.grid
    depotLocations = scenario.depotLocations

    # Generate predicted demand
    averageDemand = generatePredictedDemand(grid, historicRequestFiles)
    vehicleDemand = generatePredictedVehiclesDemand(grid, gamma, averageDemand)

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    # Initialize current state 
    initialVehicleSchedules = [VehicleSchedule(vehicle,true) for vehicle in scenario.vehicles] # TODO change constructor
    finalSolution = Solution(initialVehicleSchedules, 0.0, 0, 0, 0.0, 0) # TODO change constructor
    currentState = State(scenario,Request(),0)

    # Get solution for initial solution (offline problem)
    initialSolution, initialRequestBank = simpleConstruction(scenario,scenario.offlineRequests) 
    
    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Intitial before  ALNS")
        println("----------------")
        printSolution(initialSolution,printRouteHorizontal)
    end
    if displayPlots
        #display(createGantChartOfSolutionOnline(initialSolution,"Initial Solution"))
        display(plotRoutes(initialSolution,scenario,initialRequestBank,"Initial Solution"))
    end

    # Run ALNS for offline solution 
    # TODO: set correct parameters for alns
    solution,requestBank = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters_offline.json",initialSolution =  initialSolution, requestBank = initialRequestBank, displayPlots = displayALNSPlots, saveResults = saveALNSResults)
    requestBankOffline = deepcopy(requestBank)

    # Update time windows 
    updateTimeWindowsOnline!(solution,scenario)

    # Print routes
    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Intitial after ALNS")
        println("----------------")
        printSolution(solution,printRouteHorizontal)
    end
    if displayPlots
        #display(createGantChartOfSolutionOnline(solution,"Initial Solution after ALNS"))
        display(plotRoutes(solution,scenario,requestBank,"Initial Solution after ALNS"))
    end

    # Initialize visited routes 
    visitedRoute = Dict{Int,Dict{String,Int}}()

    # Get solution for online problem
    averageResponseTime = 0
    startSimulation = time()
    eventsInsertedByALNS = 0
    totalEvents = length(scenario.onlineRequests)
    for (itr,event) in enumerate(scenario.onlineRequests)
        startTimeEvent = time()
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Event: id: ", itr, ", time: ", event.callTime, " request id: ", event.id)
        println("----------------")

        # Determine current state
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario,visitedRoute,grid,depotLocations,vehicleDemand,relocateVehicles=relocateVehicles)
        
        if printResults
            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Current solution: ")
            println("----------------")
            printSolution(currentState.solution,printRouteHorizontal)

            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Final solution: ")
            println("----------------")
            printSolution(finalSolution,printRouteHorizontal)
        end
     
        
        # CHeck feasibility 
        feasible, msg = checkSolutionFeasibilityOnline(scenario,currentState)
        if !feasible
            println("INFEASIBLE SOLUTION IN ITERATION:", itr)
            println(msg)
            return currentState
        end

  
        # Get solution for online problem
        solution, requestBank,insertedByALNS = onlineAlgorithm(currentState, requestBank, scenario, destroyMethods, repairMethods) 
        endTimeEvent = time()
        averageResponseTime += endTimeEvent - startTimeEvent
        eventsInsertedByALNS += insertedByALNS 


        if printResults
            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Solution after online: ")
            println("----------------")
            printSolution(currentState.solution,printRouteHorizontal)
        end

        if displayPlots && event.id in requestBank
            #display(createGantChartOfSolutionAndEventOnline(solution,"Current Solution, event: "*string(event.id)*", time: "*string(event.callTime),eventId = event.id,eventTime = event.callTime, event=event))
            display(plotRoutesOnline(solution,scenario,requestBank,event,"Current Solution: event id:"*string(event.id)*" event: "*string(itr)*"/"*string(totalEvents)*", time: "*string(event.callTime)))       
        elseif displayPlots
           # display(createGantChartOfSolutionOnline(solution,"Current Solution, event: "*string(event.id)*", time: "*string(event.callTime),eventId = event.id,eventTime = event.callTime))
           display(plotRoutesOnline(solution,scenario,requestBank,event,"Current Solution: event id:"*string(event.id)*" event: "*string(itr)*"/"*string(totalEvents)*", time: "*string(event.callTime)))       
        end

    end

    # Update final solution with last state 
    mergeCurrentStateIntoFinalSolution!(finalSolution,solution,scenario)
    endSimulation = time()
    totalElapsedTime = endSimulation - startSimulation
    averageResponseTime /= length(scenario.onlineRequests)

    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Final solution after merge: ")
        println("----------------")
        printSolution(finalSolution,printRouteHorizontal)
        println("Request bank: ", requestBank)
    end
    if displayPlots
        display(createGantChartOfSolutionOnline(finalSolution,"Final Solution after merge"))
        display(plotRoutes(finalSolution,scenario,requestBank,"Final solution after merge"))
    end


    # Print summary 
    println(rpad("Metric", 40), "Value")
    println("-"^45)
    println(rpad("Unserviced offline requests", 40), length(requestBankOffline),"/",length(scenario.offlineRequests))
    println(rpad("Unserviced online requests", 40), length(setdiff(requestBank, requestBankOffline)),"/",length(scenario.onlineRequests))
    println(rpad("Final cost", 40), finalSolution.totalCost)
    println(rpad("Final distance", 40), finalSolution.totalDistance)
    println(rpad("Final ride time (veh)", 40), finalSolution.totalRideTime)
    println(rpad("Final idle time", 40), finalSolution.totalIdleTime)
    println(rpad("Total elapsed time (sim)", 40),totalElapsedTime)
    println(rpad("Average response time (sim)", 40),averageResponseTime)
    println(rpad("Events inserted by ALNS", 40),eventsInsertedByALNS)

    if saveResults
        if !isdir(outPutFileFolder)
            mkpath(outPutFileFolder)
        end
        fileName = outPutFileFolder*"/Simulation_KPI_"*string(scenario.name)*".json"
        writeOnlineKPIsToFile(fileName,scenario,finalSolution,requestBank,requestBankOffline,totalElapsedTime,averageResponseTime,eventsInsertedByALNS)
    end
    

    return finalSolution, requestBank

end


end