module SolutionUtils

using UnPack, domain, ..RouteUtils

export checkSolutionFeasibility

#==
# Function to check feasibility of solution 
==#
function checkSolutionFeasibility(scenario::Scenario,solution::Solution)
    @unpack vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, idleTime = solution

    # Collect ids of all activities in scenario - assuming activities have id 1:2*nRequests
    nRequests = length(scenario.requests)
    activityIds = collect(1:(2*nRequests))
    nActivities = length(activityIds)

    # Keep track of serviced activities assuming that activity 
    servicedActivities = Set{Int}()

    # Keep track of cost, total distance and total time of solution
    totalCostCheck = 0.0 
    totalRideTimeCheck = 0
    totalDistanceCheck = 0.0
    # TODO: keep track of idle time 

    # Check all routes 
    for vehicleSchedule in vehicleSchedules
        feasible, msg, servicedActivitiesInRoute = checkRouteFeasibility(scenario,vehicleSchedule)

        # Return if route is not feasible 
        if !feasible
            return false, msg
        end

        # Update serviced activities
        for activity in servicedActivitiesInRoute
            if activity in servicedActivities
                msg = "SOLUTION INFEASIBLE: Activity $(activity) is serviced more than once"
                return false, msg
            end

            push!(servicedActivities,activity)
        end

        totalCostCheck += vehicleSchedule.totalCost
        totalRideTimeCheck += vehicleSchedule.totalTime
        totalDistanceCheck += vehicleSchedule.totalDistance
    end

    # Check that all activities are serviced
    if (nActivities-length(servicedActivities)) != 2*nTaxi # TODO: add check if we add list of activities serviced by taxi 
        msg = "SOLUTION INFEASIBLE: Not all activities are serviced"
        return false, msg
    end

    # Check cost, distance and time of solution 
    if totalCostCheck != totalCost
        msg = "SOLUTION INFEASIBLE: Total cost of solution is incorrect. Calculated: $(totalCostCheck), actual: $(totalCost)"
        return false, msg
    end
    if totalDistanceCheck != totalDistance
        msg = "SOLUTION INFEASIBLE: Total distance of solution is incorrect. Calculated: $(totalDistanceCheck), actual: $(totalDistance)"
        return false, msg
    end
    if totalRideTimeCheck != totalRideTime
        msg = "SOLUTION INFEASIBLE: Total ride time of solution is incorrect. Calculated: $(totalRideTimeCheck), actual: $(totalRideTime)"
        return false, msg
    end


    return true, ""
    
end


end 