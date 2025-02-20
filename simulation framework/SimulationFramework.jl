
module SimulationFramework

include("../offlinesolution/src/ConstructionHeuristic.jl")

using utils
using domain
using .ConstructionHeuristic

export simulateScenario

# ------
# Function to update current state if entire route has been served and vehicle is not available anymore
# ------
function currentUpdateNotAvailableAnymore(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    # Update current state
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
    currentSchedule.route = schedule.route[end]
    currentSchedule.activeTimeWindow = TimeWindow(schedule.route[end].endOfServiceTime, schedule.route[end].endOfServiceTime)
    currentSchedule.numberOfWalking = [0]
    currentSchedule.numberOfWheelchair = [0]

    # Update final solution


    return currentSchedule
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function currentUpdateStillAvailableAndFree(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    # Update current state
    waitingDepot = ActivityAssignment(Activity(node.activity.id,-1,WAITING,WALKING,node.activity.location,TimeWindow(node.endOfServiceTime,currentTime)),schedule.vehicle,currentTime,schedule.vehicle.availableTimeWindow.endTime)
    endDepot = schedule.route[end]
    currentSchedule = currentState.solution.vehicleSchedules[vehicle] 
    currentSchedule.route = [waitingDepot,endDepot]
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.activeTimeWindow.startTime = currentTime

    # Update final solution

    return currentSchedule
end


# ------
# Function to update current state if vehicle is not available yet
# ------
function currentUpdateNotAvailableYet(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state)
    # Update current state
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
    currentSchedule = schedule

    return currentSchedule
end


# ------
# Function to update current state if vehicle have not been assigned yet
# ------
function currentUpdateNoAssignement(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state)
    # Update current state
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime

    return currentSchedule
end


# ------
# Function to update current state if vehicle have visited some
# ------
function currentUpdateSplit(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]
        
    # Update vehicle schedule for current state
    currentSchedule.route = schedule.route[idx+1:end]
    currentSchedule.activeTimeWindow = TimeWindow(currentTime,currentTime) ## TODO
    currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
    currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
    currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]

    return currentSchedule
end


# ------
# Function to update final solution
# ------
function updateFinalSolution(finalSolution::Solution,solution::Solution,vehicle::Int,idx::Int)
    
    # Update completed routes
    append!(finalSolution.vehicleSchedules[vehicle].route, schedule.route[1:idx])
    finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = currentTime
    finalSolution.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(finalSolution.vehicleSchedules[vehicle].route,scenario)
    finalSolution.vehicleSchedules[vehicle].totalTime += getTotalTimeRoute(finalSolution.vehicleSchedules[vehicle])
    finalSolution.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,finalSolution.vehicleSchedules[vehicle])
    finalSolution.vehicleSchedules[vehicle].numberOfWalking = schedule.numberOfWalking[1:idx]
    finalSolution.vehicleSchedules[vehicle].numberOfWheelchair = schedule.numberOfWheelchair[1:idx]

    return finalSolution
end



# ------
# Function to update final solution KPIs
# ------
function updateSolutionKPIs(finalSolution::Solution,solution::Solution,vehicle::Int)
        # Update completed state
        finalSolution.totalCost += finalSolution.vehicleSchedules[vehicle].totalCost
        finalSolution.totalDistance += finalSolution.vehicleSchedules[vehicle].totalDistance
        finalSolution.nTaxi += solution.nTaxi
        
        # TODO: add calculation of idle time 

        return finalSolution
end

# ------
# Function to update current State KPIs
# ------
function updateCurrentKPIs(currentSolution::Solution,vehicle::Int)
    # Update completed state
    currentSolution.totalCost += currentSolution.vehicleSchedules[vehicle].totalCost
    currentSolution.totalDistance += currentSolution.vehicleSchedules[vehicle].totalDistance
    currentSolution.nTaxi = 0
    
    # TODO: add calculation of idle time 

    return finalSolution
end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,finalSolution::Solution,scenario::Scenario)

    # Initialize current state
    currentState = State(scenario,event)

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)

        # Check if entire route has been served and vehicle is not available anymore
        if schedule.route[end].endOfServiceTime < currentTime 

            currentSchedule, idx = currentUpdateNotAvailableAnymore(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE1")
            continue

        # Check if entire route has been served and vehicle is still available
        elseif schedule.route[end-1].endOfServiceTime < currentTime && schedule.vehicle.availableTimeWindow.endTime > currentTime

            currentSchedule, idx = currentUpdateStillAvailableAndFree(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE2")
            continue
        
        # Check if vehicle is not available yet
        elseif schedule.route[1].startOfServiceTime > currentTime

            currentSchedule, idx = currentUpdateNotAvailableYet(schedule,vehicle,currentTime,currentState)
            println("HERE3")
            continue

        # Check if vehicle have not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].endOfServiceTime >= currentTime

            currentSchedule, idx = currentUpdateNoAssignement(schedule,vehicle,currentTime,currentState)
            println("HERE4")
            continue
        
        end


        # Determine index to split
        for (idx,node) in enumerate(schedule.route)
            if node.endOfServiceTime < currentTime && schedule.route[idx+1].endOfServiceTime > currentTime

                currentSchedule, idx  = currentUpdateSplit(schedule,vehicle,currentTime,currentState,finalSolution)
                println("HERE5")
                break
            end
        end

        # Update final solution
        finalSolution = updateFinalSolution(finalSolution,solution,vehicle,idx)

        # Update current schedule
        currentState.solution.vehicleSchedules[vehicle] = currentSchedule

        # Update current state KPIs
        currentState = updateCurrentKPIs(currentState.solution,vehicle)

        # Update final solution KPIs
        finalSolution = updateSolutionKPIs(finalSolution,solution,vehicle)

        
    end


    return currentState, finalSolution


end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario)

    # Initialize current state 
    initialVehicleSchedules = [VehicleSchedule(vehicle,[]) for vehicle in scenario.vehicles]
    finalSolution = Solution(initialVehicleSchedules, 0.0, 0, 0, 0, 0)
    currentState = State(scenario)

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

        for schedule in currentState.vehicleSchedules
            printRoute(schedule)
        end


        # Get solution for online problem
        #solution = onlineAlgorithm(currentState, event, scenario) # TODO: Change to right function name !!!!!!!!!!
    end

    return solution

end





end