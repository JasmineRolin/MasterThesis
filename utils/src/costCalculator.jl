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

function getTotalTimeRoute(schedule::VehicleSchedule)
    return schedule.activeTimeWindow.endTime - schedule.activeTimeWindow.startTime
end

function getTotalCostRoute(scenario::Scenario,vehicleSchedule::VehicleSchedule)
    totalTime = getTotalTimeRoute(vehicleSchedule)
    return scenario.vehicleCostPrHour * totalTime + scenario.vehicleStartUpCost
end

function getTotalCostRoute(scenario::Scenario,totalTime::Float64)
    return scenario.vehicleCostPrHour * totalTime + scenario.vehicleStartUpCost
end

end