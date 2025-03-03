module RepairMethods 

using utils, UnPack, domain
using ..ALNSDomain

export greedyInsertion
export regretInsertion

#==
 Module that containts repair methods 
==#
# TODO: implement methods 
# TODO: methods should all have same input (solution,parameters)


#== 
    Method that performs regret insertion of requests
==#
function regretInsertion(state::ALNSState,scenario::Scenario)
    #TODO should we always ensure there is an empty route?
    #TODO should we implement noise?
    @unpack destroyWeights, repairWeights, destroyNumberOfUses, repairNumberOfUses, bestSolution, currentSolution, requestBank = state
    requests = scenario.requests

    # Define insertion matrix
    insCostMatrix = zeros(Float64, length(requests), length(scenario.vehicles))
    matPossible = ones(Bool, length(requests), length(scenario.vehicles))
    fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, matPossible)

    # Insert requests
    while !isempty(requestBank)
        bestRegret = typemin(Float64)
        bestRequest = -1
        overallBestVehicle = -1
        
        # Find best request and vehicle combination to insert
        for r in requestBank
            bestVehicleForRequest = -1
            bestInsertion = secondBestInsertion = typemax(Float64)
            for v in 1:length(scenario.vehicles)
                if matPossible[requests[r].id,v]
                    if insCostMatrix[requests[r].id] < bestInsertion
                        secondBestInsertion = bestInsertion
                        bestInsertion = insCostMatrix[requests[r].id]
                        bestVehicleForRequest = v
                    elseif insCostMatrix[requests[r].id] < secondBestInsertion
                        secondBestInsertion = insCostMatrix[requests[r].id]
                    end
                end
            end
            if bestVehicleForRequest == -1
                println("regretInsertion: No feasible vehicle for request. This should not happen")
            end
            if (secondBestInsertion - bestInsertion) > bestRegret
                bestRegret = secondBestInsert - bestInsertion
                bestRequest = r
                overallBestVehicle = bestVehicleForRequest
            end
        end

        # Find best insertion position
        status, delta, pickUp, dropOff, bestTypeOfSeat = findBestFeasibleInsertionRoute(request, schedule, scenario)

        # Insert request
        insertRequest!(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], pickUp, dropOff, bestTypeOfSeat, scenario)

        # Remove request from requestBank
        deleteat!(requestBank, findfirst(requestBank, bestRequest))

        # Recalculate insertion cost matrix
        reCalcCostMatrix!(overallBestRoute, scenario, currentSolution, requestBank, insCostMatrix, matPossible)
    end


end

function fillInsertionCostMatrix!(scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, matPossible::Array{Bool,2})
    
    for r in requestBank
        for v in 1:length(scenario.vehicles)
            if matPossible[r,v]
                status, delta, pickUp, dropOff, bestTypeOfSeat = findBestFeasibleInsertionRoute(scenario.requests[r], currentSolution.vehicleSchedules[v], scenario)
                if status
                    insCostMatrix[r,v] = delta
                else
                    insCostMatrix[r,v] = typemax(Float64)
                    matPossible[r,v] = false
                end
            end
        end
    end
    
end

function reCalcCostMatrix!(v::Int,scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, matPossible::Array{Bool,2})
    for r in requestBank
        if matPossible[r,v]
            status, delta, pickUp, dropOff, bestTypeOfSeat = findBestFeasibleInsertionRoute(scenario.requests[r], currentSolution.vehicleSchedules[v], scenario)
            if status
                insCostMatrix[r,v] = delta
            else
                insCostMatrix[r,v] = typemax(Float64)
                matPossible[r,v] = false
            end
        end
    end

end


#== 
    Method that performs greedy insertion of requests
==#
function greedyInsertion(state::ALNSState,scenario::Scenario)
    @unpack destroyWeights, repairWeights, destroyNumberOfUses, repairNumberOfUses, bestSolution, currentSolution, requestBank = state

    for r in requestBank
        request = scenario.requests[r]
        bestDelta = typemax(Float64)
        bestSchedule = VehicleSchedule()
        bestPickUp = -1
        bestDropOff = -1
        bestTypeOfSeat = nothing

        for schedule in currentSolution.vehicleSchedules
            status, delta, pickUp, dropOff, bestTypeOfSeat = findBestFeasibleInsertionRoute(request, schedule, scenario)
            if status && delta < bestDelta
                bestDelta = delta
                bestSchedule = schedule
                bestPickUp = pickUp
                bestDropOff = dropOff
            end
        end
        if !isnothing(bestTypeOfSeat)
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, bestTypeOfSeat, scenario)
        else
            currentSolution.nTaxi += 1
            println("greedyInsertion: No feasible vehicle for request. This should not happen")
        end
    end

    return currentSolution
end


function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario)
    bestDelta = typemax(Float64)
    bestPickUp = -1
    bestDropOff = -1
    bestTypeOfSeat = nothing
    route = vehicleSchedule.route

    for i in 1:length(route)-1
        for j in i:length(route)-1
            feasible, typeOfSeat = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario)
            if feasible
                delta = calculateInsertionCost(request, vehicleSchedule, i, j, scenario)
                if delta < bestDelta
                    bestDelta = delta
                    bestPickUp = i
                    bestDropOff = j
                    bestTypeOfSeat = typeOfSeat
                end
            end
        end
    end

    return bestDelta < typemax(Float64), bestDelta, bestPickUp, bestDropOff, bestTypeOfSeat

end


function calculateInsertionCost(request::Request, vehicleSchedule::VehicleSchedule, i::Int, j::Int, scenario::Scenario)
    # Calculate cost of inserting request at position i,j in route
    newVehicleSchedule = copyVehicleSchedule(vehicleSchedule)
    updateRoute!(scenario.time,scenario.serviceTimes,newVehicleSchedule,request,i,j)
    newTotalCost = getTotalCostRoute(scenario,newVehicleSchedule.route)
    return newTotalCost - vehicleSchedule.totalCost
end


end


