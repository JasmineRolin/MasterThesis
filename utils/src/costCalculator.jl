module costCalculator

export getTotalDistanceRoute
export getTotalCostRoute

function getTotalDistanceRoute(route::Vector{Int},scenario::Scenario)
    nRequests = length(scenario.requests)
    totalDistance = 0
    distanceMatrix = scenario.distanceMatrix

    for i in 1:length(route)-1
        if route[i].request.activity == "PICKUP" && route[i+1].request.activity == "PICKUP"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id]
        elseif route[i].request.activity == "DROPOFF" && route[i+1].request.activity == "DROPOFF"
            totalDistance += distanceMatrix[route[i].request.id+nRequests, route[i+1].request.id+nRequests]
        elseif route[i].request.activity == "PICKUP" && route[i+1].request.activity == "DROPOFF"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id+nRequests]
        elseif route[i].request.activity == "DROPOFF" && route[i+1].request.activity == "PICKUP"
            totalDistance += distanceMatrix[route[i].request.id+nRequests, route[i+1].request.id]
        elseif route[i].request.activity == "PICKUP" && route[i+1].request.activity == "DEPOT"
            totalDistance += distanceMatrix[route[i].request.id, route[i].request.id]
        elseif route[i].request.activity == "DROPOFF" && route[i+1].request.activity == "DEPOT"
            totalDistance += distanceMatrix[route[i].request.id+nRequests, route[i].request.id]
        elseif route[i].request.activity == "DEPOT" && route[i+1].request.activity == "PICKUP"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id]
        elseif route[i].request.activity == "DEPOT" && route[i+1].request.activity == "DROPOFF"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id+nRequests]
        end
        totalDistance += distanceMatrix[route[i], route[i+1]]
    end
    return totalDistance
end

function getTotalCostRoute(totalDistance::Float32, scenario::Scenario)
    return scenario.vehicleCostPerKm * totalDistance
end

end