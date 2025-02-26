
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
    currentSchedule.numberOfWalking = [0]
    currentSchedule.numberOfWheelchair = [0]

    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1 

    return idx, currentSchedule.activeTimeWindow.startTime
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function updateCurrentScheduleStillAvailableAndFree!(scenario::Scenario,schedule::VehicleSchedule,currentState::State,vehicle::Int,currentTime::Int)

    # Create waiting activity at location of last activity if possible 
    availableTimeWindowEnd = schedule.vehicle.availableTimeWindow.endTime
    endOfServiceTimeWaiting = availableTimeWindowEnd - scenario.time[schedule.route[end-1].activity.id,schedule.route[end].activity.id]

    depot = schedule.route[end]

    # If the vehicle can wait at the last location
    if endOfServiceTimeWaiting > currentTime
        endOfServiceTimeLastActivity = schedule.route[end-1].endOfServiceTime
        
        # Create waiting activity that start at the end of service of last location - start time of waiting activity is in the past 
        waitingActivity = Activity(schedule.route[end-1].activity.id,-1,WAITING,WALKING,schedule.route[end-1].activity.location,TimeWindow(endOfServiceTimeLastActivity,endOfServiceTimeWaiting))
        waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,endOfServiceTimeLastActivity,endOfServiceTimeWaiting) 

        # Update times of depot 
        depot.startOfServiceTime = availableTimeWindowEnd
        depot.endOfServiceTime = availableTimeWindowEnd
        depot.activity.timeWindow.startTime = endOfServiceTimeLastActivity
        depot.activity.timeWindow.endTime = availableTimeWindowEnd

        # Retrieve empty schedule and update it 
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        # Update route 
        currentSchedule.route = [waitingAssignment,depot]

        # Update active time window 
        currentSchedule.activeTimeWindow.startTime = endOfServiceTimeLastActivity
        currentSchedule.activeTimeWindow.endTime = endOfServiceTimeWaiting

        # Update KPIs
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)
        currentSchedule.numberOfWalking = [0,0]
        currentSchedule.numberOfWheelchair = [0,0]

    # If the vehicle cannot wait at the last location - then we wait at depot
    elseif depot.startOfServiceTime != availableTimeWindowEnd
        # Retrieve empty schedule and update it 
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        # Create waiting activity at depot 
        startOfWaiting = depot.startOfServiceTime
        waitingActivity = Activity(depot.activity.id,-1,WAITING,WALKING,depot.activity.location,TimeWindow(startOfWaiting,availableTimeWindowEnd))
        waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,startOfWaiting,availableTimeWindowEnd) 

        # Update route 
        currentSchedule.route = [waitingAssignment,depot]

        # Update active time window
        currentSchedule.activeTimeWindow.startTime = startOfWaiting
        currentSchedule.activeTimeWindow.endTime = availableTimeWindowEnd

        # Update depot 
        depot.startOfServiceTime = availableTimeWindowEnd
        depot.endOfServiceTime = availableTimeWindowEnd

        # Update KPIs
        currentSchedule.totalDistance = 0.0
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)
        currentSchedule.numberOfWalking = [0,0]
        currentSchedule.numberOfWheelchair = [0,0]
    
    # We finish the route at the depot 
    else
        # Retrieve empty schedule and update it 
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        # Create waiting activity at depot 
        startOfWaiting = depot.startOfServiceTime
        waitingActivity = Activity(depot.activity.id,-1,WAITING,WALKING,depot.activity.location,TimeWindow(startOfWaiting,availableTimeWindowEnd))
        waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,startOfWaiting,availableTimeWindowEnd) 

        # Update route 
        currentSchedule.route = [depot]

        # Update active time window
        currentSchedule.activeTimeWindow.startTime = availableTimeWindowEnd
        currentSchedule.activeTimeWindow.endTime = availableTimeWindowEnd

        # Update depot 
        depot.startOfServiceTime = availableTimeWindowEnd
        depot.endOfServiceTime = availableTimeWindowEnd

        # Update KPIs
        currentSchedule.totalDistance = 0.0
        currentSchedule.totalTime = 0
        currentSchedule.totalCost = 0.0
        currentSchedule.totalIdleTime = 0
        currentSchedule.numberOfWalking = [0]
        currentSchedule.numberOfWheelchair = [0]
    end

    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1

    return idx, currentSchedule.activeTimeWindow.startTime
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
    currentSchedule.route[1].activity.timeWindow.startTime = currentTime
    currentSchedule.route[1].startOfServiceTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime

    currentSchedule.route[end].activity.timeWindow.startTime = currentTime 
    currentSchedule.route[end].startOfServiceTime = currentTime
    currentSchedule.route[end].endOfServiceTime = currentTime

    # index to split route into current and completed route
    idx = 0

    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle has visited some customers 
# ------
function updateCurrentScheduleAtSplit!(scenario::Scenario,schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,idx::Int)
    
    # Retrieve empty schedule to update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
        
    # Determine whether there is time to wait
    canWait = schedule.route[idx].endOfServiceTime + scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id] < schedule.route[idx+1].startOfServiceTime

    # If there is time to wait 
    if canWait
        # Determine end of waiting activity as the latest time the vehicle has to leave the latest activity 
        endOfServiceTimeWaiting = schedule.route[idx+1].startOfServiceTime - scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id]

        # If there is time to wait at latest location
        if endOfServiceTimeWaiting > currentTime
            endOfServiceTimeLastActivity = schedule.route[idx].endOfServiceTime

            # Create waiting activity at location of last activity - assume that there is time to wait 
            waitingActivity = Activity(schedule.route[idx].activity.id,-1,WAITING,WALKING,schedule.route[idx].activity.location,TimeWindow(endOfServiceTimeLastActivity,endOfServiceTimeWaiting))
            waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,endOfServiceTimeLastActivity,endOfServiceTimeWaiting)

            # Update route 
            currentSchedule.route = [waitingAssignment; schedule.route[idx+1:end]]

            # Update active time window 
            currentSchedule.activeTimeWindow.startTime = endOfServiceTimeLastActivity 
            currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

        # If there is no time to wait at previous location - waiting is inserted at next location 
        else schedule.route[idx].endOfServiceTime + scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id] < schedule.route[idx+1].startOfServiceTime 
           
            # Create waiting activity at location of next activity 
            waitingActivity = Activity(schedule.route[idx+1].activity.id,-1,WAITING,WALKING,schedule.route[idx+1].activity.location,TimeWindow(currentTime,schedule.route[idx+1].startOfServiceTime))
            waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,currentTime,schedule.route[idx+1].startOfServiceTime)
    
            # Update schedule 
            currentSchedule.route = [waitingAssignment; schedule.route[idx+1:end]]

            # Update active time window 
            currentSchedule.activeTimeWindow.startTime = currentTime 
            currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime  
        end

        # Update KPIs
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)
        currentSchedule.numberOfWalking = [schedule.numberOfWalking[idx]; schedule.numberOfWalking[idx+1:end]] 
        currentSchedule.numberOfWheelchair = [schedule.numberOfWheelchair[idx]; schedule.numberOfWheelchair[idx+1:end]]

    # Update vehicle schedule for current state with no waiting
    else
        # Update route 
        currentSchedule.route = schedule.route[idx+1:end]

        # Update active time window
        currentSchedule.activeTimeWindow.startTime = schedule.route[idx+1].startOfServiceTime 
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

        # Update KPIs
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
        currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
        currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]
    end

    return idx, currentSchedule.activeTimeWindow.startTime
end

# ------
# Function to update current state if vehicle has visited some customers and waiting activity needs to be split 
# ------
function updateCurrentScheduleSplitWaitingActivity!(scenario::Scenario,schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,idx::Int)
    
    # Retrieve empty schedule to update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
        
    # Split waiting activity 
    waitingActivity = schedule.route[idx].activity
    waitingActivityInCompleted = Activity(waitingActivity.id,-1,WAITING,WALKING,waitingActivity.location,TimeWindow(waitingActivity.timeWindow.startTime,currentTime))
    waitingActivityInCurrent = Activity(waitingActivity.id,-1,WAITING,WALKING,waitingActivity.location,TimeWindow(currentTime,waitingActivity.timeWindow.endTime))

    # Insert waiting activity in route in schedule 
    waitingActivityAssignmentInCompleted = ActivityAssignment(waitingActivityInCompleted,schedule.vehicle,waitingActivity.timeWindow.startTime,currentTime)
    insert!(schedule.route,idx,waitingActivityAssignmentInCompleted)
    insert!(schedule.numberOfWalking,idx,schedule.numberOfWalking[idx])
    insert!(schedule.numberOfWheelchair,idx,schedule.numberOfWheelchair[idx])

    # Update route in current schedule 
    waitingActivityAssignmentInCurrent = ActivityAssignment(waitingActivityInCurrent,schedule.vehicle,currentTime,waitingActivity.timeWindow.endTime)
    schedule.route[idx+1] = waitingActivityAssignmentInCurrent
    currentSchedule.route = schedule.route[idx+1:end]

    # Update active time window in current schedule 
    currentSchedule.activeTimeWindow.startTime = currentTime 
    currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

    # Update KPIs
    currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
    currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)
    currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
    currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]

    return idx, currentSchedule.activeTimeWindow.startTime
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
   
    # Update KPIs of route
    totalTimeOfNewCompletedRoute = splitTime - newCompletedRoute[1].startOfServiceTime
    finalSolution.vehicleSchedules[vehicle].totalTime += totalTimeOfNewCompletedRoute
    finalSolution.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(solution.vehicleSchedules[vehicle].route[1:idx+1],scenario)
    finalSolution.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,totalTimeOfNewCompletedRoute) # Do not add start up cost
    finalSolution.vehicleSchedules[vehicle].totalIdleTime += getTotalIdleTimeRoute(newCompletedRoute)
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair, solution.vehicleSchedules[vehicle].numberOfWheelchair[1:idx])

    # # Update KPIs of solution
    finalSolution.totalRideTime += totalTimeOfNewCompletedRoute
    finalSolution.totalDistance += getTotalDistanceRoute(solution.vehicleSchedules[vehicle].route[1:idx+1],scenario)
    finalSolution.totalCost += getTotalCostRoute(scenario,totalTimeOfNewCompletedRoute) # Do not add start up cost
    finalSolution.idleTime += getTotalIdleTimeRoute(newCompletedRoute)
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

        finalSolution.vehicleSchedules[vehicle].totalDistance += newDistance
        finalSolution.vehicleSchedules[vehicle].totalTime += newDuration
        finalSolution.vehicleSchedules[vehicle].totalCost += newCost
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += newIdleTime
        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)
        finalSolution.vehicleSchedules[vehicle].numberOfWheelchair = append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair,schedule.numberOfWheelchair)

         # Update KPIs of solution
        finalSolution.totalRideTime += newDuration
        finalSolution.totalDistance += newDistance
        finalSolution.totalCost += newCost + scenario.vehicleStartUpCost # TODO: should start up cost only be for active vehicles?
        finalSolution.idleTime += schedule.totalIdleTime
    end
end

# ------
# Function determine whether to split route at index 
# ------
function splitRouteAtIndex(schedule::VehicleSchedule,assignment::ActivityAssignment,currentTime::Int,split::Int)
    splitWaitingActivity = assignment.activity.activityType == WAITING && assignment.startOfServiceTime <= currentTime && assignment.endOfServiceTime >= currentTime
    splitRoute = assignment.endOfServiceTime < currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
    return splitRoute, splitWaitingActivity
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

        # Check if vehicle is not available yet or hasnt started service yet
        if schedule.vehicle.availableTimeWindow.startTime > currentTime || schedule.route[1].startOfServiceTime > currentTime
            idx, splitTime = updateCurrentScheduleNotAvailableYet(schedule,currentState,vehicle)
            print(" - not available yet or not started service yet \n")

        # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime < currentTime
            idx, splitTime = updateCurrentScheduleNotAvailableAnymore!(currentState,schedule,vehicle)
            print(" - not available anymore \n")

        # Check if vehicle has not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT
            idx, splitTime = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
            print(" - no assignments \n")

        # Check if entire route has been served and vehicle is still available
        elseif schedule.route[end-1].endOfServiceTime < currentTime && schedule.vehicle.availableTimeWindow.endTime > currentTime
            idx, splitTime = updateCurrentScheduleStillAvailableAndFree!(scenario,schedule,currentState,vehicle,currentTime)
            print(" - still available and route completed \n")

        else
            # Determine index to split
            for (split,assignment) in enumerate(schedule.route)
               splitRoute, splitWaitingActivity = splitRouteAtIndex(schedule,assignment,currentTime,split)

               if splitWaitingActivity
                    idx, splitTime = updateCurrentScheduleSplitWaitingActivity!(scenario,schedule,vehicle,currentTime,currentState,split)
                    print(" - still available, split waiting activity at ",split, ", \n")
                    break 
               elseif splitRoute
                    idx, splitTime  = updateCurrentScheduleAtSplit!(scenario,schedule,vehicle,currentTime,currentState,split)
                    print(" - still available, split at ",split, ", \n")
                    break
                end
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
    initialVehicleSchedules = [VehicleSchedule(vehicle,ActivityAssignment[]) for vehicle in scenario.vehicles] # TODO change constructor
    finalSolution = Solution(initialVehicleSchedules, 0.0, 0, 0, 0, 0) # TODO change constructor
    currentState = State(scenario,Request())

    # Get solution for initial solution (online problem)
    # solution = offlineAlgorithm(scenario) # TODO: Change to right function name !!!!!!!!!!
    solution = Solution(scenario)
    solution = simpleConstruction(scenario)

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

    return finalSolution

end

end