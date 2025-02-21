
module SimulationFramework

using utils
using domain
using offlinesolution

export simulateScenario

# ------
# Function to update current state if entire route has been served and vehicle is not available anymore
# ------
function currentUpdateNotAvailableAnymore(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,finalSolution::Solution)
    # Update current state
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
    currentSchedule.route = [schedule.route[end]]
    currentSchedule.activeTimeWindow = TimeWindow(schedule.route[end].endOfServiceTime, schedule.route[end].endOfServiceTime)
    currentSchedule.numberOfWalking = [0]
    currentSchedule.numberOfWheelchair = [0]
    idx = length(schedule.route)-1

    return currentSchedule, idx
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function currentUpdateStillAvailableAndFree(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,finalSolution::Solution)
    # Update current state
    waitingDepot = ActivityAssignment(Activity(schedule.route[end-1].activity.id,-1,WAITING,WALKING,schedule.route[end-1].activity.location,TimeWindow(schedule.route[end-1].endOfServiceTime,currentTime)),schedule.vehicle,currentTime,schedule.vehicle.availableTimeWindow.endTime)
    endDepot = schedule.route[end]
    currentSchedule = currentState.solution.vehicleSchedules[vehicle] 
    currentSchedule.route = [waitingDepot,endDepot]
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.activeTimeWindow.startTime = currentTime
    idx = length(schedule.route)-1

    return currentSchedule, idx
end


# ------
# Function to update current state if vehicle is not available yet
# ------
function currentUpdateNotAvailableYet(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State)
    # Update current state
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
    currentSchedule = schedule
    idx = 0

    return currentSchedule, idx
end


# ------
# Function to update current state if vehicle have not been assigned yet
# ------
function currentUpdateNoAssignement(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State)
    # Update current state
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime
    idx = 0

    return currentSchedule, idx
end


# ------
# Function to update current state if vehicle have visited some
# ------
function currentUpdateSplit(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::State,finalSolution::Solution,idx::Int,scenario::Scenario)
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
        
    # Update vehicle schedule for current state with waiting
    if schedule.route[idx].endOfServiceTime + scenario.distance[schedule.route[idx].activity.id,schedule.route[idx+1].activity.id] < schedule.route[idx+1].startOfServiceTime
        waitingDepot = ActivityAssignment(Activity(schedule.route[idx].activity.id,-1,WAITING,WALKING,schedule.route[idx].activity.location,TimeWindow(schedule.route[idx].endOfServiceTime,currentTime)),schedule.vehicle,currentTime,schedule.vehicle.availableTimeWindow.endTime)
        currentSchedule.route = append([waitingDepot],schedule.route[idx+1:end])
        currentSchedule.activeTimeWindow.startTime = currentTime 
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
        currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]

    # Update vehicle schedule for current state with no waiting
    else
        currentSchedule.route = schedule.route[idx+1:end]
        currentSchedule.activeTimeWindow.startTime = currentTime 
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
        currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
        currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]

    end

    return currentSchedule,idx
end


# ------
# Function to update final solution
# ------
function updateFinalSolution!(finalSolution::Solution,solution::Solution,vehicle::Int,currentTime::Int,idx::Int,scenario::Scenario)
    
    # Update completed routes
    append!(finalSolution.vehicleSchedules[vehicle].route, solution.vehicleSchedules[vehicle].route[1:idx])
    finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = currentTime
    finalSolution.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(finalSolution.vehicleSchedules[vehicle].route,scenario)
    finalSolution.vehicleSchedules[vehicle].totalTime += getTotalTimeRoute(finalSolution.vehicleSchedules[vehicle])
    finalSolution.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle])
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWheelchair, solution.vehicleSchedules[vehicle].numberOfWheelchair[1:idx])

end



# ------
# Function to update final solution KPIs
# ------
function updateSolutionKPIs!(finalSolution::Solution,solution::Solution,vehicle::Int) #TODO not correct
        # Update completed state
        finalSolution.totalCost += finalSolution.vehicleSchedules[vehicle].totalCost
        finalSolution.totalDistance += finalSolution.vehicleSchedules[vehicle].totalDistance
        finalSolution.nTaxi += solution.nTaxi
        
        # TODO: add calculation of idle time 

end

# ------
# Function to update current State KPIs
# ------
function updateCurrentKPIs!(currentSolution::Solution,vehicle::Int)
    # Update completed state
    currentSolution.totalCost += currentSolution.vehicleSchedules[vehicle].totalCost
    currentSolution.totalDistance += currentSolution.vehicleSchedules[vehicle].totalDistance
    currentSolution.nTaxi = 0
    
    # TODO: add calculation of idle time 

end

# ------
# Function to merge current State and final solution in last iteration
# ------
function mergeCurrentIntoFinal!(finalSolution::Solution,currentState::State)
    for (vehicle,schedule) in enumerate(currentState.solution.vehicleSchedules)
        finalSolution.vehicleSchedules[vehicle].route = append!(finalSolution.vehicleSchedules[vehicle].route,schedule.route)
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow = schedule.activeTimeWindow
        finalSolution.vehicleSchedules[vehicle].totalDistance += schedule.totalDistance
        finalSolution.vehicleSchedules[vehicle].totalTime += schedule.totalTime
        finalSolution.vehicleSchedules[vehicle].totalCost += schedule.totalCost
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

        
        # Check if vehicle have not been assigned yet
        if length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].endOfServiceTime >= currentTime

            currentSchedule, idx = currentUpdateNoAssignement(schedule,vehicle,currentTime,currentState)
            println("HERE4")

        # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime < currentTime 

            currentSchedule, idx = currentUpdateNotAvailableAnymore(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE1")

        # Check if entire route has been served and vehicle is still available
        elseif schedule.route[end-1].endOfServiceTime < currentTime && schedule.vehicle.availableTimeWindow.endTime > currentTime

            currentSchedule, idx = currentUpdateStillAvailableAndFree(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE2")
        
        # Check if vehicle is not available yet
        elseif schedule.route[1].startOfServiceTime > currentTime

            currentSchedule, idx = currentUpdateNotAvailableYet(schedule,vehicle,currentTime,currentState)
            println("HERE3")
        
        else
            # Determine index to split
            for (idx2,node) in enumerate(schedule.route)
                if node.endOfServiceTime < currentTime && schedule.route[idx2+1].endOfServiceTime > currentTime

                    currentSchedule, idx  = currentUpdateSplit(schedule,vehicle,currentTime,currentState,finalSolution,idx2,scenario)
                    println("HERE5")

                    break
                end
            end
        end

        # Update current schedule
        currentState.solution.vehicleSchedules[vehicle] = currentSchedule

        # Update current state KPIs
        updateCurrentKPIs!(currentState.solution,vehicle)

        # Update final solution
        updateFinalSolution!(finalSolution,solution,vehicle,currentTime,idx,scenario)

        # Update final solution KPIs
        #updateSolutionKPIs!(finalSolution,solution,vehicle)

        
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
        printRoute(schedule)
    end

    # Get solution for online problem
    for (itr,event) in enumerate(scenario.onlineRequests)
        println("----------------")
        println("Event: ", event.callTime)
        println("----------------")

        # Determine current state
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario)

        for schedule in currentState.solution.vehicleSchedules
            printRoute(schedule)
        end

        println("----------------")
        println("Final solution: ")
        println("----------------")
        for schedule in finalSolution.vehicleSchedules
            printRoute(schedule)
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
        printRoute(schedule)
    end

    return solution

end





end