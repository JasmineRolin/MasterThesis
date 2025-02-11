
module SimulationFramework

using utils

# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Request)

    # Initialize current state
    currentState = State()
    completedRoutes = Vector{VehicleSchedule}()

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (i,vehicle) in enumerate(solution.vehicleSchedule)
        for (j,assignment) in enumerate(vehicle.requestAssignments)
            if assignment.endOfServiceTime < currentTime
                currentState.vehicleSchedule[i].requestAssignments = assignment[j:end]
                completededRoute[i] = assignment[1:j-1]
                break
            end
        end
        
    end

    
    # Update total cost
    currentState.totalCost = currentObjectiveFunction(completedRoutes) #Change to right function name !!!!!!!!!!

    return currentState


end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario)

    # Get online and offline requests
    onlineRequests, offlineRequests = splitRequests(scenario.requests)

    # Get solution for initial solution (online problem)
    solution = offlineAlgorithm(offlineRequests, scenario) #Change to right function name !!!!!!!!!!

    # Get solution for online problem
    for (itr,event) in enumerate(onlineRequests)
        # Determine current state 
        currentState = determineCurrentState(solution, event)


        solution = onlineAlgorithm(currentState, event) #Change to right function name !!!!!!!!!!
    end

    return solution

end





end