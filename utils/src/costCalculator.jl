module costCalculator

export getTotalDistanceRoute
export getTotalCostRoute

function getTotalDistanceRoute(route::Vector{Int}, distanceMatrix::Matrix{Int},scenario::Scenario)
    nRequests = length(scenario.requests)
    totalDistance = 0
    for i in 1:length(route)-1
        if route[i].request.task == "PICKUP" && route[i+1].request.task == "PICKUP"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id]
        elseif route[i].request.task == "DROPOFF" && route[i+1].request.task == "DROPOFF"
            totalDistance += distanceMatrix[route[i].request.id+nRequests, route[i+1].request.id+nRequests]
        elseif route[i].request.task == "PICKUP" && route[i+1].request.task == "DROPOFF"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id+nRequests]
        elseif route[i].request.task == "DROPOFF" && route[i+1].request.task == "PICKUP"
            totalDistance += distanceMatrix[route[i].request.id+nRequests, route[i+1].request.id]
        elseif route[i].request.task == "PICKUP" && route[i+1].request.task == "DEPOT"
            totalDistance += distanceMatrix[route[i].request.id, route[i].request.id]
        elseif route[i].request.task == "DROPOFF" && route[i+1].request.task == "DEPOT"
            totalDistance += distanceMatrix[route[i].request.id+nRequests, route[i].request.id]
        elseif route[i].request.task == "DEPOT" && route[i+1].request.task == "PICKUP"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id]
        elseif route[i].request.task == "DEPOT" && route[i+1].request.task == "DROPOFF"
            totalDistance += distanceMatrix[route[i].request.id, route[i+1].request.id+nRequests]
        end
        totalDistance += distanceMatrix[route[i], route[i+1]]
    end
    return totalDistance
end

function getTotalCostRoute(route::Vector{Int}, costMatrix::Matrix{Float32})
    totalCost = 0
    for i in 1:length(route)-1
        totalCost += costMatrix[route[i].request, route[i+1]]
    end
    return totalCost


end

end