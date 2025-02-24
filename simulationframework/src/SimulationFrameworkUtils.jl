
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
    idx = length(schedule.route) - 1 # TODO: jas - det giver 0?

    return idx
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
# We wait as long as possible at the last activity until we have to drive to the depot
function updateCurrentScheduleStillAvailableAndFree!(scenario::Scenario,schedule::VehicleSchedule,currentState::State,vehicle::Int,currentTime::Int)
   
    # Create waiting activity at location of last activity 
    availableTimeWindowEnd = schedule.vehicle.availableTimeWindow.endTime
    endOfServiceTimeWaiting = availableTimeWindowEnd - scenario.time[schedule.route[end-1].activity.id,schedule.route[end].activity.id]
    # TODO: jas - do we need to consider if this can be before current time ? 

    waitingActivity = Activity(schedule.route[end-1].activity.id,-1,WAITING,WALKING,schedule.route[end-1].activity.location,TimeWindow(schedule.route[end-1].endOfServiceTime,endOfServiceTimeWaiting))
    waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,currentTime,endOfServiceTimeWaiting) 

    # Update times of depot 
    depot = schedule.route[end]
    depot.startOfServiceTime = availableTimeWindowEnd
    depot.endOfServiceTime = availableTimeWindowEnd
    depot.activity.timeWindow.startTime = currentTime
    depot.activity.timeWindow.endTime = availableTimeWindowEnd

    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    currentSchedule.route = [waitingAssignment,depot]
    currentSchedule.activeTimeWindow.startTime = currentTime
    currentSchedule.activeTimeWindow.endTime = availableTimeWindowEnd
    currentSchedule.totalDistance = scenario.distance[waitingActivity.id,schedule.route[end].activity.id]
    currentSchedule.totalTime = availableTimeWindowEnd - currentTime
    currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
    currentSchedule.totalIdleTime = 0
    currentSchedule.numberOfWalking = [0,0]
    currentSchedule.numberOfWheelchair = [0,0]

    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1

    return idx
end


# ------
# Function to update current state if vehicle is not available yet
# ------
function updateCurrentScheduleNotAvailableYet()

    # TODO: jas - should we update depots times? 

    # index to split route into current and completed route
    idx = 0

    return idx
end

# ------
# Function to update current state if vehicle has not started service yet
# ------
function updateCurrentScheduleNotAvailableYet(schedule::VehicleSchedule,currentState::State,vehicle::Int)
    # update current schedule 
    currentState.solution.vehicleSchedules[vehicle] = schedule
    
    # index to split route into current and completed route
    idx = 0

    return idx
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

    # index to split route into current and completed route
    idx = 0

    return idx
end


# ------
# Function to update current state if vehicle have visited some
# ------
function updateCurrentScheduleAtSplit!(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,idx::Int,scenario::Scenario)
    
    # Retrieve empty schedule and update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
        
    # Update vehicle schedule for current state with waiting
    if schedule.route[idx].endOfServiceTime + scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id] < schedule.route[idx+1].startOfServiceTime

        # Create waiting activity at location of last activity - assume that there is time to wait 
        endOfServiceTimeWaiting = schedule.route[idx+1].startOfServiceTime - scenario.time[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id]
        waitingActivity = Activity(schedule.route[idx].activity.id,-1,WAITING,WALKING,schedule.route[idx].activity.location,TimeWindow(currentTime,endOfServiceTimeWaiting))
        waitingAssignment = ActivityAssignment(waitingActivity,schedule.vehicle,currentTime,endOfServiceTimeWaiting)

        # Update schedule 
        currentSchedule.route = [waitingAssignment; schedule.route[idx+1:end]]
        currentSchedule.activeTimeWindow.startTime = currentTime 
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)
        currentSchedule.numberOfWalking = [schedule.numberOfWalking[idx+1]; schedule.numberOfWalking[idx+1:end]] 
        currentSchedule.numberOfWheelchair = [schedule.numberOfWheelchair[idx+1]; schedule.numberOfWheelchair[idx+1:end]]
        
    # Update vehicle schedule for current state with no waiting
    else
        currentSchedule.route = schedule.route[idx+1:end]
        currentSchedule.activeTimeWindow.startTime = currentTime 
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
        currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
        currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]
    end

    return idx
end


# ------
# Function to update final solution for given vehicle 
# ------
function updateFinalSolution!(finalSolution::Solution,solution::Solution,vehicle::Int,currentTime::Int,idx::Int,scenario::Scenario)
    # Return if no completed route 
    if idx == 0
        return
    end

    # Update completed routes
    newCompletedRoute =  solution.vehicleSchedules[vehicle].route[1:idx]
    append!(finalSolution.vehicleSchedules[vehicle].route, newCompletedRoute)

    finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = currentTime

    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair, solution.vehicleSchedules[vehicle].numberOfWheelchair[1:idx])

    # Update KPIs
    totalTimeOfNewCompletedRoute = currentTime - newCompletedRoute[1].startOfServiceTime
    finalSolution.vehicleSchedules[vehicle].totalTime += totalTimeOfNewCompletedRoute
    finalSolution.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(newCompletedRoute,scenario)
    finalSolution.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,totalTimeOfNewCompletedRoute)
    finalSolution.vehicleSchedules[vehicle].totalIdleTime += getTotalIdleTimeRoute(newCompletedRoute)
end



# ------
# Function to update final solution KPIs
# ------
# function updateSolutionKPIs!(finalSolution::Solution,solution::Solution,vehicle::Int) #TODO not correct
#         # Update completed state
#         finalSolution.totalCost += finalSolution.vehicleSchedules[vehicle].totalCost
#         finalSolution.totalDistance += finalSolution.vehicleSchedules[vehicle].totalDistance
#         finalSolution.nTaxi += solution.nTaxi
        
#         # TODO: add calculation of idle time 

# end

# ------
# Function to update current State KPIs
# # ------
# function updateCurrentKPIs!(currentSolution::Solution,vehicle::Int)
#     # Update completed state
#     currentSolution.totalCost += currentSolution.vehicleSchedules[vehicle].totalCost
#     currentSolution.totalDistance += currentSolution.vehicleSchedules[vehicle].totalDistance
#     currentSolution.nTaxi = 0
    
#     # TODO: add calculation of idle time 

# end

# ------
# Function to merge current State and final solution in last iteration
# ------
function mergeCurrentIntoFinal!(finalSolution::Solution,currentState::State)
    # Loop through all schedules and add to final solution 
    for (vehicle,schedule) in enumerate(currentState.solution.vehicleSchedules)

        finalSolution.vehicleSchedules[vehicle].route = append!(finalSolution.vehicleSchedules[vehicle].route,schedule.route)

        finalSolution.vehicleSchedules[vehicle].activeTimeWindow = schedule.activeTimeWindow
        finalSolution.vehicleSchedules[vehicle].totalDistance += schedule.totalDistance
        finalSolution.vehicleSchedules[vehicle].totalTime += schedule.totalTime
        finalSolution.vehicleSchedules[vehicle].totalCost += schedule.totalCost
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += schedule.totalIdleTime

        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)
        finalSolution.vehicleSchedules[vehicle].numberOfWheelchair = append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair,schedule.numberOfWheelchair)

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

            idx = updateCurrentScheduleNotAvailableYet()
            print(" - not available yet or not started service yet \n")

         # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime < currentTime 

            idx = updateCurrentScheduleNotAvailableAnymore!(currentState,schedule,vehicle)
            print(" - not available anymor \n")

        # Check if vehicle have not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT

            idx = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
            print(" - no assignments \n")

        # Check if entire route has been served and vehicle is still available
        elseif schedule.route[end-1].endOfServiceTime < currentTime && schedule.vehicle.availableTimeWindow.endTime > currentTime
            idx = updateCurrentScheduleStillAvailableAndFree!(scenario,schedule,currentState,vehicle,currentTime)
            print(" - still available and route completed \n")

        else
            # Determine index to split
            for (split,node) in enumerate(schedule.route)
               if node.endOfServiceTime < currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
                    idx  = updateCurrentScheduleAtSplit!(schedule,vehicle,currentTime,currentState,split,scenario)
                    print(" - still available, split at ",split, ", \n")
                    break
                end
            end
        end

        # Update final solution
        updateFinalSolution!(finalSolution,solution,vehicle,currentTime,idx,scenario)
        
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
    for schedule in solution.vehicleSchedules
        printRouteHorizontal(schedule)
    end

    # Get solution for online problem
    for (itr,event) in enumerate(scenario.onlineRequests)
        println("----------------")
        println("Event: ", event.callTime)
        println("----------------")

        # Determine current state
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario)

        for schedule in currentState.solution.vehicleSchedules
            printRouteHorizontal(schedule)
        end

        println("----------------")
        println("Final solution: ")
        println("----------------")
        for schedule in finalSolution.vehicleSchedules
            printRouteHorizontal(schedule)
        end

        # Get solution for online problem
        #solution = onlineAlgorithm(currentState, event, scenario) # TODO: Change to right function name !!!!!!!!!!
        solution = currentState.solution # Only for test as long as onlineAlgorithm is not implemented
    end

    mergeCurrentIntoFinal!(finalSolution::Solution,currentState::State)

    println("----------------")
    println("Final solution: ")
    println("----------------")
    for schedule in finalSolution.vehicleSchedules
        printRouteHorizontal(schedule)
    end

    return solution

end





end