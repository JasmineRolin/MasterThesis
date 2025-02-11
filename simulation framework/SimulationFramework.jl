
module SimulationFramework

using utils

# ------
# Function to determine current KPIs
# ------
function currentKPIs(completedRoutes::Vector{VehicleSchedule},oldState::State)

    for route in completedRoutes
        # Update KPIs

    end

    return totalCost, nTaxi, totalRideTime, totalViolationTW, totalDistance, idleTime

end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request,oldState::State,completedRoutes::Vector{VehicleSchedule})

    # Initialize current state
    currentState = State()

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)
        for (idx,node) in enumerate(schedule.route)
            if node.endOfServiceTime < currentTime
                # Update vehicle schedule for current state
                currentState.vehicleSchedules[vehicle].route = schedule.route[j:end]
                currentState.vehicleSchedules[vehicle].totalDistance = getTotalDistanceRoute(currentState.vehicleSchedules[vehicle].route)
                currentState.vehicleSchedules[vehicle].totalCost = getTotalCostRoute(currentState.vehicleSchedules[vehicle].route)

                # Update completed routes
                append!(completedRoutes[vehicle], schedule.route[1:j-1])
                break
            end
        end
        
    end

    # Update KPIs
    currentState.totalCost, currentState.nTaxi, currentState.totalRideTime, currentState.totalViolationTW, currentState.totalDistance, currentState.idleTime = currentKPIs(completedRoutes,oldState) #Change to right function name !!!!!!!!!!

    return currentState, completedRoutes


end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario)

    # Initialize current state 
    oldState = State()
    currentState = State()
    completedRoutes = Vector{VehicleSchedule}()

    # Get solution for initial solution (online problem)
    solution = offlineAlgorithm(scenario) #Change to right function name !!!!!!!!!!

    # Get solution for online problem
    for (itr,event) in enumerate(onlineRequests)
        # Determine current state 
        oldState = copy(currentState)
        currentState = determineCurrentState(solution, event, oldState, completedRoutes)

        # Get solution for online problem
        solution = onlineAlgorithm(currentState, event, scenario) #Change to right function name !!!!!!!!!!
    end

    return solution

end





end