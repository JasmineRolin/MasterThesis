
module SimulationFramework

using utils
using domain
using offlinesolution

export simulateScenario

# ------
# Function to update current state if entire route has been served and vehicle is not available anymore
# ------
function updateCurrentScheduleNotAvailableAnymore!(currentState::State,schedule::VehicleSchedule,vehicle::Int)
   
    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update schedule with only end  depot for unavailable vehicle 
    currentSchedule.route = [schedule.route[end]]
    currentSchedule.activeTimeWindow.startTime = schedule.route[end].endOfServiceTime
    currentSchedule.activeTimeWindow.endTime = schedule.route[end].endOfServiceTime

    # Update KPIs
    currentSchedule.totalDistance = 0.0
    currentSchedule.totalTime = 0
    currentSchedule.totalCost = 0.0
    currentSchedule.totalIdleTime = 0
    currentSchedule.numberOfWalking = [0]

    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1 

    return idx, currentSchedule.activeTimeWindow.startTime
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function updateCurrentScheduleRouteCompleted!(currentState::State,schedule::VehicleSchedule,vehicle::Int)
   
    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    arrivalAtDepot = schedule.route[end].startOfServiceTime
    endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime

    # Create waiting activity to replace depot activity
    waitingActivityCompletedRoute = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), schedule.vehicle,arrivalAtDepot,endOfAvailableTimeWindow)

    # Update schedule with only  depots for  vehicle 
    currentSchedule.route[1] = waitingActivityCompletedRoute
    currentSchedule.route[end].activity.timeWindow = TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)
    currentSchedule.activeTimeWindow.startTime = arrivalAtDepot
    currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow

    # Update KPIs
    currentSchedule.totalDistance = 0.0
    currentSchedule.totalTime = 0
    currentSchedule.totalCost = 0.0
    currentSchedule.totalIdleTime = endOfAvailableTimeWindow - arrivalAtDepot
    currentSchedule.numberOfWalking = [0,0]

    # Index to split route into current and completed route 
    idx = length(schedule.route)-1

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
    
    # Retrieve empty schedule to update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update route 
    currentSchedule.route = schedule.route[idx+1:end]

    # Update active time window
    currentSchedule.activeTimeWindow.startTime = schedule.route[idx+1].startOfServiceTime 
    currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

    # Update KPIs
    currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.route)
    currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
    currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]


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
function updateFinalSolution!(scenario::Scenario,finalSolution::Solution,solution::Solution,vehicle::Int,idx::Int,splitTime::Int)
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
    finalSolution.vehicleSchedules[vehicle].totalTime += totalTimeOfNewCompletedRoute

    endIndex = (idx == length(solution.vehicleSchedules[vehicle].route)) ? idx : idx + 1
    totalDistance = getTotalDistanceRoute(solution.vehicleSchedules[vehicle].route[1:endIndex],scenario)
    totalCost = getTotalCostRoute(scenario,solution.vehicleSchedules[vehicle].route[1:endIndex]) 
    totalIdleTime = getTotalIdleTimeRoute(newCompletedRoute)

    finalSolution.totalCost -= finalSolution.vehicleSchedules[vehicle].totalCost # TODO: change  

    finalSolution.vehicleSchedules[vehicle].totalDistance += totalDistance
    finalSolution.vehicleSchedules[vehicle].totalCost = getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle].route) # totalCost # TODO: change 
    finalSolution.vehicleSchedules[vehicle].totalIdleTime += totalIdleTime
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])

    finalSolution.totalRideTime += totalTimeOfNewCompletedRoute
    finalSolution.totalDistance += totalDistance
    finalSolution.totalCost += finalSolution.vehicleSchedules[vehicle].totalCost # TODO: change 
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
        finalSolution.vehicleSchedules[vehicle].totalCost = getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle].route) # += newCost # TODO: change
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += newIdleTime


        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)

        # Update KPIs of solution
        finalSolution.totalRideTime += newDuration
        finalSolution.totalDistance += newDistance
        finalSolution.totalIdleTime += newIdleTime
        finalSolution.totalCost += getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle].route)#  newCost # TODO: change
    end
end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,finalSolution::Solution,scenario::Scenario)

    # Initialize current state
    currentState = State(scenario,event)
    idx = -1
    splitTime = -1

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)
        print("UPDATING SCHEDULE: ",vehicle)

        if vehicle == 11 
            println("")
        end

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
        updateFinalSolution!(scenario,finalSolution,solution,vehicle,idx, splitTime)
        
    end

    return currentState, finalSolution
end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario)

    # Initialize current state 
    initialVehicleSchedules = [VehicleSchedule(vehicle,true) for vehicle in scenario.vehicles] # TODO change constructor
    finalSolution = Solution(initialVehicleSchedules, 0.0, 0, 0, 0, 0) # TODO change constructor
    currentState = State(scenario,Request())

    # Get solution for initial solution (online problem)
    # solution = offlineAlgorithm(scenario) # TODO: Change to right function name !!!!!!!!!!
    solution = Solution(scenario)
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests) 

    feasible, msg = checkSolutionFeasibility(scenario,solution,scenario.offlineRequests)

    # Update final solution with initial solution
    finalSolution.nTaxi += length(requestBank) 
    finalSolution.totalCost = getTaxiCostOfSolution(scenario,finalSolution)

    println("Request bank: ", requestBank)

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
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario)

        println("----------------")
        println("current solution: ")
        println("----------------")
        printSolution(currentState.solution,printRouteHorizontal)
     


        println("----------------")
        println("Final solution: ")
        println("----------------")
        printSolution(finalSolution,printRouteHorizontal)

        # Get solution for online problem
        # solution = onlineAlgorithm(currentState, event, scenario) # TODO: Change to right function name !!!!!!!!!!
        solution = currentState.solution # Only for test as long as onlineAlgorithm is not implemented
    end

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