
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
                # Update vehicle schedule for current state
                currentState.vehicleSchedules[vehicle].route = schedule.route[j:end]
                currentState.vehicleSchedules[vehicle].totalDistance = getTotalDistanceRoute(currentState.vehicleSchedules[vehicle].route,scenario)
                currentState.vehicleSchedules[vehicle].totalCost = getTotalCostRoute(scenario,currentState.vehicleSchedules[vehicle].route)
                currentState.totalCost += currentState.vehicleSchedules[vehicle].totalCost
                currentState.totalDistance += currentState.vehicleSchedules[vehicle].totalDistance
                currentState.nTaxi = 0

                # Update completed routes
                append!(completedState.vehicleSchedules[vehicle], schedule.route[1:j-1])
                completedState.vehicleSchedules[vehicle].totalDistance += getTotalDistanceRoute(completedState.vehicleSchedules[vehicle].route,scenario)
                completedState.vehicleSchedules[vehicle].totalCost += getTotalCostRoute(scenario,completedState.vehicleSchedules[vehicle].route)
                completedState.totalCost += completedState.vehicleSchedules[vehicle].totalCost
                completedState.totalDistance += completedState.vehicleSchedules[vehicle].totalDistance
                completedState.nTaxi += solution.nTaxi
                break
            end
        end
        
    end

    # Update KPIs
    currentState.totalRideTime, currentState.idleTime = currentKPIs(currentState) #Change to right function name !!!!!!!!!!
    completedState.totalRideTime, completedState.idleTime = currentKPIs(completedState) #Change to right function name !!!!!!!!!!

    return currentState, completedState


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

    # Get solution for online problem
    for (itr,event) in enumerate(scenario.onlineRequests)
        # Determine current state
        #currentState, completedState = determineCurrentState(solution,event,completedState,scenario)

        # Get solution for online problem
        #solution = onlineAlgorithm(currentState, event, scenario) #Change to right function name !!!!!!!!!!
    end

    return solution

end





end