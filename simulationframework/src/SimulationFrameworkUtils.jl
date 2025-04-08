
module SimulationFramework

using utils
using domain
using offlinesolution
using onlinesolution
using alns

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

    println("===========================> Length currentSchedule: ", length(currentSchedule.route))
    println("==============================> arrival at depot: ",arrivalAtDepot)

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
    println("---------------HERE-------------")
    println("Visited route: ", currentState.visitedRoute)
    currentSchedule.totalCost = getTotalCostRouteOnline(scenario.time,currentSchedule.route,currentState.visitedRoute,scenario.serviceTimes)
    println(currentSchedule.totalCost)
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
function mergeCurrentStateIntoFinalSolution!(finalSolution::Solution,currentState::State,scenario::Scenario)

    # Loop through all schedules and add to final solution 
    for (vehicle,schedule) in enumerate(currentState.solution.vehicleSchedules)

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
        newDuration = duration(schedule.activeTimeWindow)
        newCost = schedule.totalCost 
        newIdleTime = schedule.totalIdleTime

        finalSolution.totalCost -= finalSolution.vehicleSchedules[vehicle].totalCost # TODO: change


        finalSolution.vehicleSchedules[vehicle].totalDistance += newDistance
        finalSolution.vehicleSchedules[vehicle].totalTime += newDuration
        finalSolution.vehicleSchedules[vehicle].totalCost = getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle].route) # += newCost # TODO: jas - change
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += newIdleTime


        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)

        # Update KPIs of solution
        finalSolution.totalRideTime += newDuration
        finalSolution.totalDistance += newDistance
        finalSolution.totalIdleTime += newIdleTime
        finalSolution.totalCost += getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle].route)#  newCost # TODO: jas - change
    end

    finalSolution.nTaxi += currentState.solution.nTaxi
    finalSolution.totalCost += scenario.taxiParameter*finalSolution.nTaxi

end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,finalSolution::Solution,scenario::Scenario,visitedRoute::Dict{Int,Dict{String,Int}})

    # Initialize current state
    currentState = State(scenario,event,visitedRoute,0)
    currentState.solution.vehicleSchedules = deepcopy(solution.vehicleSchedules)
    currentState.solution.totalCost = solution.totalCost
    currentState.solution.nTaxi = 0 #?solution.nTaxi
    currentState.solution.totalDistance = solution.totalDistance
    currentState.solution.totalRideTime = solution.totalRideTime
    currentState.solution.totalIdleTime = solution.totalIdleTime
    idx = -1
    splitTime = -1

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)
        print("UPDATING SCHEDULE: ",vehicle)

        # Check if vehicle is not available yet or has not started service yet
        if schedule.vehicle.availableTimeWindow.startTime > currentTime || schedule.route[1].startOfServiceTime > currentTime
            idx, splitTime = updateCurrentScheduleNotAvailableYet(schedule,currentState,vehicle)
            print(" - not available yet or not started service yet \n")
        # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime < currentTime 
            idx, splitTime = updateCurrentScheduleNotAvailableAnymore!(currentState,schedule,vehicle)
            print(" - not available anymore \n")
        # We have completed the last activity and the vehicle is on-route to the depot but still available 
        elseif schedule.route[end-1].activity.activityType != DEPOT && schedule.route[end-1].endOfServiceTime < currentTime
            idx,splitTime = updateCurrentScheduleRouteCompleted!(currentState,schedule,vehicle)
            print("- completed route but still available \n")
        # Check if vehicle has not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT
            idx, splitTime = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
            print(" - no assignments \n")
        else
            # Determine index to split
            didSplit = false
            for (split,assignment) in enumerate(schedule.route)
               if assignment.endOfServiceTime < currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
                    idx, splitTime  = updateCurrentScheduleAtSplit!(scenario,schedule,vehicle,currentState,split)
                    didSplit = true
                    print(" - still available, split at ",split, ", \n")
                    break
                end
            end

            if didSplit == false
                idx, splitTime = updateCurrentScheduleAvailableKeepEntireRoute(schedule,currentState,vehicle)
                print(" - still available, keep entire route, \n")
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
function simulateScenario(scenario::Scenario)

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
    finalSolution = Solution(initialVehicleSchedules, 0.0, 0, 0, 0, 0) # TODO change constructor
    currentState = State(scenario,Request(),0)

    # Get solution for initial solution (offline problem)
    # solution = offlineAlgorithm(scenario) # TODO: Change to right function name !!!!!!!!!!
    # TODO: jas - skal alns ikke køres ? 
    solution = Solution(scenario)
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests) 

    visitedRoute = Dict{Int,Dict{String,Int}}()

    # Print routes
    println("------------------------------------------------------------------------------------------------------------------------------------------------")
    println("Intitial")
    println("----------------")
    printSolution(solution,printRouteHorizontal)

    # Get solution for online problem
    for (itr,event) in enumerate(scenario.onlineRequests)
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Event: id: ", itr, ", time: ", event.callTime)
        println("----------------")

        # Determine current state
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario,visitedRoute)
        currentState.totalNTaxi = finalSolution.nTaxi
        
        println("----------------")
        println("Current solution: ")
        println("----------------")
        println(visitedRoute)
        printSolution(currentState.solution,printRouteHorizontal)
     


        println("----------------")
        println("Final solution solution: ")
        println("----------------")
        printSolution(finalSolution,printRouteHorizontal)

        # CHeck feasibility 
        feasible, msg = checkSolutionFeasibilityOnline(scenario,currentState)
        if !feasible
            println("INFEASIBLE SOLUTION IN ITERATION:", itr)
            println(msg)
            return currentState
        end

        if itr == 0
            # Update time windows for all requests in solution
            updateTimeWindowsOnlineAll!(currentState.solution,scenario)
        end        


        # Get solution for online problem
        # TODO: jas - hvorfor returnerer den npget her ? 
        solution, requestBank = onlineAlgorithm(currentState, requestBank, scenario, destroyMethods, repairMethods) 
    
        # println("----------------")
        # println("Solution after online: ")
        # println("----------------")
        # printSolution(currentState.solution,printRouteHorizontal)



    end

    println("----------------")
    println("Final Solution before merge: ")
    println("----------------")
    printSolution(finalSolution,printRouteHorizontal)

    # Update final solution with last state 
    mergeCurrentStateIntoFinalSolution!(finalSolution,currentState,scenario)

    println("------------------------------------------------------------------------------------------------------------------------------------------------")
    println("Final solution after merge: ")
    println("----------------")
    printSolution(finalSolution,printRouteHorizontal)

    println("Request bank: ", requestBank)


    return finalSolution

end

end