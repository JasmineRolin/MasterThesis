
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
# We wait as long as possible at the last activity until we have to drive to the depot
function updateCurrentScheduleStillAvailableAndFree!(scenario::Scenario,schedule::VehicleSchedule,currentState::State,vehicle::Int,currentTime::Int)
    
    idx = 0 
    splitTime = 0

    # Create waiting activity at location of last activity if possible 
    availableTimeWindowEnd = schedule.vehicle.availableTimeWindow.endTime
    endOfServiceTimeWaiting = availableTimeWindowEnd - scenario.time[schedule.route[end-1].activity.id,schedule.route[end].activity.id]

    # If the vehicle can wait at the last location
    if endOfServiceTimeWaiting > currentTime
        endOfServiceTimeLastActivity = schedule.route[end-1].endOfServiceTime
        
        # Create waiting activity that start at the end of service of last location 
        # Start time of waiting activity is in the past 
        waitingActivity = Activity(schedule.route[end-1].activity.id,-1,WAITING,WALKING,schedule.route[end-1].activity.location,TimeWindow(endOfServiceTimeLastActivity,endOfServiceTimeWaiting))
        waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,endOfServiceTimeLastActivity,endOfServiceTimeWaiting) 

        # Update times of depot 
        depot = schedule.route[end]
        depot.startOfServiceTime = availableTimeWindowEnd
        depot.endOfServiceTime = availableTimeWindowEnd
        depot.activity.timeWindow.startTime = endOfServiceTimeLastActivity
        depot.activity.timeWindow.endTime = availableTimeWindowEnd

        # Retrieve empty schedule and update it 
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        currentSchedule.route = [waitingAssignment,depot]

        currentSchedule.activeTimeWindow.startTime = endOfServiceTimeLastActivity
        currentSchedule.activeTimeWindow.endTime = endOfServiceTimeWaiting

        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)
        currentSchedule.numberOfWalking = [0,0]
        currentSchedule.numberOfWheelchair = [0,0]

        # Index to split route into current and completed route 
        idx = length(schedule.route) - 1

        # Time at which the schedules are split 
        splitTime = endOfServiceTimeLastActivity

    # If the vehicle cannot wait at the last location
    else
        # Retrieve empty schedule and update it 
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        depot = schedule.route[end]

        currentSchedule.route = [depot]

        currentSchedule.activeTimeWindow.startTime = depot.startOfServiceTime
        currentSchedule.activeTimeWindow.endTime = depot.startOfServiceTime

        currentSchedule.totalDistance = 0.0
        currentSchedule.totalTime = 0
        currentSchedule.totalCost = 0
        currentSchedule.totalIdleTime = 0

        currentSchedule.numberOfWalking = [0]
        currentSchedule.numberOfWheelchair = [0]

        # Index to split route into current and completed route 
        idx = length(schedule.route) - 1
    end


    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle is not available yet or has not started service yet
# ------
function updateCurrentScheduleNotAvailableYet(schedule::VehicleSchedule,currentState::State,vehicle::Int)
    # update current schedule 
    currentState.solution.vehicleSchedules[vehicle] = schedule
    
    # index to split route into current and completed route
    idx = 0

    return idx, 0
end


# ------
# Function to update current state if vehicle have not been assigned yet
# ------
function updateCurrentScheduleNoAssignement!(vehicle::Int,currentTime::Int,currentState::State)
    # Retrieve empty schedule and update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.activeTimeWindow.startTime = currentTime

    currentSchedule.route[1].activity.timeWindow.startTime = currentTime
    currentSchedule.route[end].activity.timeWindow.startTime = currentTime 

    currentSchedule.route[1].startOfServiceTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime

    currentSchedule.route[end].startOfServiceTime = currentTime
    currentSchedule.route[end].endOfServiceTime = currentTime

    # index to split route into current and completed route
    idx = 0

    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle have visited some
# ------
function updateCurrentScheduleAtSplit!(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,idx::Int,scenario::Scenario)
    
    # Retrieve empty schedule and update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
        
   
    # Determine whether there is time to wait
    canWait = schedule.route[idx].endOfServiceTime + scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id] < schedule.route[idx+1].startOfServiceTime

    if canWait
        # Determine end of waiting activity as the latest time the vehicle has to leave the latest activity 
        endOfServiceTimeWaiting = schedule.route[idx+1].startOfServiceTime - scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id]

        # If there is time to wait at latest location
        if endOfServiceTimeWaiting > currentTime
            endOfServiceTimeLastActivity = schedule.route[idx].endOfServiceTime

            # Create waiting activity at location of last activity - assume that there is time to wait 
            waitingActivity = Activity(schedule.route[idx].activity.id,-1,WAITING,WALKING,schedule.route[idx].activity.location,TimeWindow(endOfServiceTimeLastActivity,endOfServiceTimeWaiting))
            waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,endOfServiceTimeLastActivity,endOfServiceTimeWaiting)

            # Update schedule 
            currentSchedule.route = [waitingAssignment; schedule.route[idx+1:end]]

            currentSchedule.activeTimeWindow.startTime = endOfServiceTimeLastActivity 
            currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

            currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
            currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
            currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
            currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)

            currentSchedule.numberOfWalking = [schedule.numberOfWalking[idx]; schedule.numberOfWalking[idx+1:end]]
            currentSchedule.numberOfWheelchair = [schedule.numberOfWheelchair[idx]; schedule.numberOfWheelchair[idx+1:end]]


        # If there is no time to wait at previous location - waiting is inserted at next location 
        else schedule.route[idx].endOfServiceTime + scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id] < schedule.route[idx+1].startOfServiceTime 
           
            # Create waiting activity at location of next activity 
            waitingActivity = Activity(schedule.route[idx+1].activity.id,-1,WAITING,WALKING,schedule.route[idx+1].activity.location,TimeWindow(currentTime,schedule.route[idx+1].startOfServiceTime))
            waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,currentTime,schedule.route[idx+1].startOfServiceTime)
    
            # Update schedule 
            currentSchedule.route = [waitingAssignment; schedule.route[idx+1:end]]

            currentSchedule.activeTimeWindow.startTime = currentTime 
            currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

            currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
            currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
            currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
            currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)

            currentSchedule.numberOfWalking = [schedule.numberOfWalking[idx]; schedule.numberOfWalking[idx+1:end]] 
            currentSchedule.numberOfWheelchair = [schedule.numberOfWheelchair[idx]; schedule.numberOfWheelchair[idx+1:end]]
        end

    # Update vehicle schedule for current state with no waiting
    else
        currentSchedule.route = schedule.route[idx+1:end]

        currentSchedule.activeTimeWindow.startTime = schedule.route[idx+1].startOfServiceTime 
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

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
# Function to update final solution for given vehicle 
# ------
function updateFinalSolution!(finalSolution::Solution,solution::Solution,vehicle::Int,currentTime::Int,idx::Int,splitTime::Int,scenario::Scenario)
    # Return if no completed route 
    if idx == 0
        return
    end

    # Update completed routes
    newCompletedRoute =  solution.vehicleSchedules[vehicle].route[1:idx]

    if length(finalSolution.vehicleSchedules[vehicle].route) == 0
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow.startTime = solution.vehicleSchedules[vehicle].activeTimeWindow.startTime
    end

    append!(finalSolution.vehicleSchedules[vehicle].route, newCompletedRoute)
   
    finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = splitTime

    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair, solution.vehicleSchedules[vehicle].numberOfWheelchair[1:idx])

    # Update KPIs of route
    totalTimeOfNewCompletedRoute = splitTime - newCompletedRoute[1].startOfServiceTime

    finalSolution.vehicleSchedules[vehicle].totalTime += totalTimeOfNewCompletedRoute
    finalSolution.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(solution.vehicleSchedules[vehicle].route[1:idx+1],scenario)
    finalSolution.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,totalTimeOfNewCompletedRoute) # Do not add start up cost
    finalSolution.vehicleSchedules[vehicle].totalIdleTime += getTotalIdleTimeRoute(newCompletedRoute)

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

        finalSolution.vehicleSchedules[vehicle].route = append!(finalSolution.vehicleSchedules[vehicle].route,schedule.route)
     
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = schedule.activeTimeWindow.endTime

        finalSolution.vehicleSchedules[vehicle].totalDistance += schedule.totalDistance
        finalSolution.vehicleSchedules[vehicle].totalTime += duration(schedule.activeTimeWindow)
        finalSolution.vehicleSchedules[vehicle].totalCost += schedule.totalCost
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += schedule.totalIdleTime

        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)
        finalSolution.vehicleSchedules[vehicle].numberOfWheelchair = append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair,schedule.numberOfWheelchair)

         # Update KPIs of solution
        finalSolution.totalRideTime += duration(schedule.activeTimeWindow)
        finalSolution.totalDistance += schedule.totalDistance
        finalSolution.totalCost += schedule.totalCost + scenario.vehicleStartUpCost # TODO: should start up cost only be for active vehicles?
        finalSolution.idleTime += schedule.totalIdleTime

    end
end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,finalSolution::Solution,scenario::Scenario)

    # Initialize current state
    currentState = State(scenario,event)
    idx = -1

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
            print(" - not available anymor \n")

        # Check if vehicle have not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT

            idx, splitTime = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
            print(" - no assignments \n")

        # Check if entire route has been served and vehicle is still available
        elseif schedule.route[end-1].endOfServiceTime < currentTime && schedule.vehicle.availableTimeWindow.endTime > currentTime
            idx, splitTime = updateCurrentScheduleStillAvailableAndFree!(scenario,schedule,currentState,vehicle,currentTime)
            print(" - still available and route completed \n")

        else
            # Determine index to split
            for (split,node) in enumerate(schedule.route)
               if node.endOfServiceTime < currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
                    idx, splitTime  = updateCurrentScheduleAtSplit!(schedule,vehicle,currentTime,currentState,split,scenario)
                    print(" - still available, split at ",split, ", \n")
                    break
                end
            end
        end

        # Update final solution
        updateFinalSolution!(finalSolution,solution,vehicle,currentTime,idx, splitTime,scenario)
        
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
    #solution = offlineAlgorithm(scenario) #Change to right function name !!!!!!!!!!
    solution = Solution(scenario)
    solution = simpleConstruction(scenario)
    # Print routes
    println("----------------")
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

    println("----------------")
    println("Final solution after merge: ")
    println("----------------")
    printSolution(finalSolution,printRouteHorizontal)

    return finalSolution

end





end