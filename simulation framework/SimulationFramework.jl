
module SimulationFramework

include("../offlinesolution/src/ConstructionHeuristic.jl")

using utils
using domain
using .ConstructionHeuristic

export simulateScenario

# ------
# Function to determine current KPIs
# ------
function currentKPIs(state::State)

    totalRideTime = 0
    idleTime = 0

    return totalRideTime, idleTime

end


# ------
# Function to update current state if entire route has been served and vehicle is not available anymore
# ------
function currentUpdateNotAvailableAnymore(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    # Update current state
    currentSchedule = currentState.vehicleSchedules[vehicle]
    currentSchedule = schedule.route[idx+1:end]


    # Update final solution

    return currentSchedule, finalSchedule
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function currentUpdateStillAvailableAndFree(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    # Update current state
    waitingDepot = ActivityAssignment(Activity(node.activity.id,-1,WAITING,WALKING,node.activity.location,TimeWindow(node.endOfServiceTime,currentTime)),schedule.vehicle,currentTime,schedule.vehicle.availableTimeWindow.endTime)
    endDepot = schedule.route[end]
    currentSchedule = currentState.vehicleSchedules[vehicle] 
    currentSchedule.route = [waitingDepot,endDepot]
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.activeTimeWindow.startTime = currentTime


    # Update final solution

    return currentSchedule, finalSchedule
end


# ------
# Function to update current state if vehicle is not available yet
# ------
function currentUpdateNotAvailableYet(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    # Update current state
    currentSchedule = currentState.vehicleSchedules[vehicle]
    currentSchedule = schedule
    # Update final solution

    return currentSchedule, finalSchedule
end


# ------
# Function to update current state if vehicle have not been assigned yet
# ------
function currentUpdateNoAssignement(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    # Update current state
    currentSchedule = currentState.vehicleSchedules[vehicle]
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime

    # Update final solution

    return currentSchedule, finalSchedule
end


# ------
# Function to update current state if vehicle have visited some
# ------
function currentUpdateSplit(schedule::VehicleSchedule,vehicle::Int,currentTime::Int,currentState::state,finalSolution::Solution)
    currentSchedule = currentState.vehicleSchedules[vehicle]
        
    # Update vehicle schedule for current state
    currentSchedule.route = schedule.route[idx+1:end]
    println("currentRouteLength",length(currentSchedule.route))
    currentSchedule.activeTimeWindow = TimeWindow(currentTime,currentTime) ## TODO
    currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
    currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]
    currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx+1:end]

    # Update current state
    currentState.totalCost += currentSchedule.totalCost
    currentState.totalDistance += currentSchedule.totalDistance
    currentState.nTaxi = 0

    # Update completed routes
    append!(completedState.vehicleSchedules[vehicle].route, schedule.route[1:idx])
    println("completedRouteLength",length(schedule.route[1:idx]))
    completedState.vehicleSchedules[vehicle].activeTimeWindow.endTime = currentTime
    completedState.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(completedState.vehicleSchedules[vehicle].route,scenario)
    completedState.vehicleSchedules[vehicle].totalTime += getTotalTimeRoute(completedState.vehicleSchedules[vehicle])
    completedState.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,completedState.vehicleSchedules[vehicle])
    completedState.vehicleSchedules[vehicle].numberOfWalking = schedule.numberOfWalking[1:idx]
    completedState.vehicleSchedules[vehicle].numberOfWheelchair = schedule.numberOfWheelchair[1:idx]

    # Update completed state
    completedState.totalCost += completedState.vehicleSchedules[vehicle].totalCost
    completedState.totalDistance += completedState.vehicleSchedules[vehicle].totalDistance
    completedState.nTaxi += solution.nTaxi
    
    # TODO: add calculation of idle time 

    return currentSchedule, finalSchedule
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

            currentSchedule, finalSolution = currentUpdateNotAvailableAnymore(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE1")
            continue

        # Check if entire route has been served and vehicle is still available
        elseif schedule.route[end-1].endOfServiceTime < currentTime && schedule.vehicle.availableTimeWindow.endTime > currentTime

            currentSchedule, finalSolution = currentUpdateStillAvailableAndFree(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE2")
            continue
        
        # Check if vehicle is not available yet
        elseif schedule.route[1].startOfServiceTime > currentTime

            currentSchedule, finalSolution = currentUpdateNotAvailableYet(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE3")
            continue

        # Check if vehicle have not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].endOfServiceTime >= currentTime

            currentSchedule, finalSolution = currentUpdateNoAssignement(schedule,vehicle,currentTime,currentState,finalSolution)
            println("HERE4")
            continue
        
        end


        # Determine index to split
        for (idx,node) in enumerate(schedule.route)
            if node.endOfServiceTime < currentTime && schedule.route[idx+1].endOfServiceTime > currentTime

                currentSchedule, finalSolution = currentUpdateSplit(schedule,vehicle,currentTime,currentState,finalSolution)
                println("HERE5")
                break
            end
        end
        
    end


    return currentState, finalSolution


end

function initializeRightCompletedState(finalSolution::Solution,solution::Solution)

    #TODO
    return finalSolution

end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario)

    # Initialize current state 
    completedState = State(scenario)
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

    # Fix initial complete state
    completedState = initializeRightCompletedState(completedState,solution)

    # Get solution for online problem
    for (itr,event) in enumerate(scenario.onlineRequests)
        println("----------------")
        println("Event: ", event.callTime)
        println("----------------")

        # Determine current state
        currentState, completedState = determineCurrentState(solution,event,completedState,scenario)

        for schedule in currentState.vehicleSchedules
            printRoute(schedule)
        end


        # Get solution for online problem
        #solution = onlineAlgorithm(currentState, event, scenario) # TODO: Change to right function name !!!!!!!!!!
    end

    return solution

end





end