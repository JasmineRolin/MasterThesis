module SolutionUtils

using UnPack, ..RouteUtils

#==
# Function to check feasibility of solution 
==#
function checkSolutionFeasibility(solution::Solution)
    @unpack vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, idleTime = solution

    # 

    # Check all routes 
    for vehicleSchedule in vehicleSchedules
        feasible, msg, servicedActivities = checkRouteFeasibility(vehicleSchedule)
    end
    
end


end 