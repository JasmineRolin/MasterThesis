module costCalculator

using domain

export getTotalDistanceRoute
export getTotalCostRoute
export getTotalTimeRoute

function getTotalDistanceRoute(route::Vector{ActivityAssignment},scenario::Scenario)
    totalDistance = 0
    distanceMatrix = scenario.distance

    for i in 1:length(route)-1
        totalDistance += distanceMatrix[route[i].activity.id, route[i+1].activity.id]
    end
    return totalDistance
end

function getTotalTimeRoute(vehicleSchedules::Vector{VehicleSchedule})
    totalTime = 0

    for schedule in vehicleSchedules
        totalTime += schedule.activeTimeWindow.endTime - schedule.activeTimeWindow.startTime
        for node in schedule.route
            if node.activity == "WAITING"
                totalTime -= node.endOfServiceTime - node.startOfServiceTime
            end
        end
    end

    return totalTime
end

function getTotalCostRoute(scenario::Scenario,vehicleSchedules::Vector{VehicleSchedule})
    totalTime = getTotalTimeRoute(vehicleSchedules)
    return scenario.vehicleCostPrHour * totalTime + scenario.vehicleStartUpCost
end

function getTotalCostRoute(scenario::Scenario,totalTime::Float64)
    return scenario.vehicleCostPrHour * totalTime + scenario.vehicleStartUpCost
end

end