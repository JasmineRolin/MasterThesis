
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
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,completedState::State,scenario::Scenario)

    # Initialize current state
    currentState = State(scenario)

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)
        for (idx,node) in enumerate(schedule.route)
            if node.endOfServiceTime < currentTime
                currentSchedule = currentState.vehicleSchedules[vehicle]

                # Update vehicle schedule for current state
                currentSchedule.route = schedule.route[idx:end]
                currentSchedule.activeTimeWindow = TimeWindow(currentTime,currentTime) ## TODO
                currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
                currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
                currentSchedule.totalCost = getTotalCostRoute(scenario,currentSchedule.totalTime)
                currentSchedule.numberOfWalking = schedule.numberOfWalking[idx:end]
                currentSchedule.numberOfWheelchair = schedule.numberOfWheelchair[idx:end]

                # Update current state
                currentState.totalCost += currentSchedule.totalCost
                currentState.totalDistance += currentSchedule.totalDistance
                currentState.nTaxi = 0

                # Update completed routes
                append!(completedState.vehicleSchedules[vehicle].route, schedule.route[1:idx-1])
                completedState.vehicleSchedules[vehicle].activeTimeWindow.endTime = currentTime
                completedState.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(completedState.vehicleSchedules[vehicle].route,scenario)
                completedState.vehicleSchedules[vehicle].totalTime += getTotalTimeRoute(completedState.vehicleSchedules[vehicle])
                completedState.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,completedState.vehicleSchedules[vehicle])
                completedState.vehicleSchedules[vehicle].numberOfWalking = schedule.numberOfWalking[1:idx-1]
                completedState.vehicleSchedules[vehicle].numberOfWheelchair = schedule.numberOfWheelchair[1:idx-1]

                # Update completed state
                completedState.totalCost += completedState.vehicleSchedules[vehicle].totalCost
                completedState.totalDistance += completedState.vehicleSchedules[vehicle].totalDistance
                completedState.nTaxi += solution.nTaxi
                
                # TODO: add calculation of idle time 

                break
            end
        end
        
    end

    # Update KPIs
    currentState.totalRideTime, currentState.idleTime = currentKPIs(currentState) # TODO: Change to right function name !!!!!!!!!!
    completedState.totalRideTime, completedState.idleTime = currentKPIs(completedState) # TODO: Change to right function name !!!!!!!!!!

    return currentState, completedState


end

function initializeRightCompletedState(completedState::State,solution::Solution)

    
    for (vehicle,schedule) in enumerate(completedState.vehicleSchedules)
        # Remove last element in completedState
        completedState.vehicleSchedules[vehicle].route = schedule.route[1:end-1]

        # Set right start of active time
        completedState.vehicleSchedules[vehicle].activeTimeWindow.startTime = solution.vehicleSchedules[vehicle].route[1].endOfServiceTime
    end

    return completedState

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