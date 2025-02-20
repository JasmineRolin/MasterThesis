module SolutionUtils

using UnPack, ..RouteUtils

#==
# Function to check feasibility of solution 
==#
function checkSolutionFeasibility(scenario::Scenario,solution::Solution)
    @unpack vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, idleTime = solution

    # Collect ids of all activities in scenario 
    activityIds = vcat([req.pickUpActivity.id, req.dropOffActivity.id] for req in scenario.requests) 
    nActivities = length(activityIds)

    # Keep track of serviced activities 
    servicedActivities = zeros(Bool,nActivities)

    # Check all routes 
    for vehicleSchedule in vehicleSchedules
        feasible, msg, servicedActivities = checkRouteFeasibility(vehicleSchedule)

        # Return if route is not feasible 
        if !feasible
            return false, msg
        end

        # Update serviced activities
        for activity in servicedActivities
            if servicedActivities[activity]
                msg = "SOLUTION INFEASIBLE: Activity $(activity) is serviced more than once"
                return false, msg
            end

            servicedActivities[activity] = true
        end
    end

    # Check that all activities are serviced


    return true 
    
end


end 