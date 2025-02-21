module CostCalculator

using domain

export getTotalDistanceRoute
export getTotalCostRoute
export getTotalTimeRoute
export getTotalCostDistanceTimeOfSolution


#==
#  Function to get total distance of a route
==# 
function getTotalDistanceRoute(route::Vector{ActivityAssignment},scenario::Scenario)
    totalDistance = 0
    distanceMatrix = scenario.distance

    for i in 1:length(route)-1
        totalDistance += distanceMatrix[route[i].activity.id, route[i+1].activity.id]
    end
    return totalDistance
end

#==
#  Function to get total time of a route
==#
function getTotalTimeRoute(vehicleSchedules::Vector{VehicleSchedule})
    totalTime = 0

    for schedule in vehicleSchedules
        totalTime += schedule.activeTimeWindow.endTime - schedule.activeTimeWindow.startTime
        for node in schedule.route
            # TODO: hvorfor bliver waiting trukket fra?
            if node.activity == "WAITING"
                totalTime -= node.endOfServiceTime - node.startOfServiceTime
            end
        end
    end

    return totalTime
end

#==
#  Function to get total cost of a route 
==#
function getTotalCostRoute(scenario::Scenario,vehicleSchedules::Vector{VehicleSchedule})
    totalTime = getTotalTimeRoute(vehicleSchedules)
    return scenario.vehicleCostPrHour * totalTime + scenario.vehicleStartUpCost
end

#==
#  Function to get total cost of a route
==#
function getTotalCostRoute(scenario::Scenario,totalTime::Int)
    return scenario.vehicleCostPrHour * totalTime + scenario.vehicleStartUpCost
end

#==
# Function to get total cost and distance of solution 
==#
function getTotalCostDistanceTimeOfSolution(solution::Solution)
    totalCost = 0.0
    totalDistance = 0.0
    totalTime = 0
    for schedule in solution.vehicleSchedules
        totalCost += schedule.totalCost
        totalDistance += schedule.totalDistance
        totalTime += schedule.totalTime
    end
    return totalCost, totalDistance, totalTime
end

end