module RepairMethods 

using utils, UnPack, domain
using ..ALNSDomain

export greedyInsertion
export regretInsertion

#== 
    Method that performs regret insertion of requests
==#
function regretInsertion(state::ALNSState,scenario::Scenario;visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())
    #println("regretInsertion: ", visitedRoute)

    #TODO should we implement noise?
    @unpack currentSolution, requestBank = state
    requests = scenario.requests

    #TODO remove when stable also in oter palces
    if length(requestBank) != state.currentSolution.nTaxi
        println(requestBank)
        throw("Error: requestBank length does not match currentSolution.nTaxi")
        return
    end

    # Define insertion matrix
    insCostMatrix = zeros(Float64, length(requests), length(scenario.vehicles))
    compatibilityRequestVehicle = ones(Bool, length(requests), length(scenario.vehicles))
    fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,visitedRoute)

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
                if compatibilityRequestVehicle[requests[r].id,v]
                    if insCostMatrix[requests[r].id,v] < bestInsertion
                        secondBestInsertion = bestInsertion
                        bestInsertion = insCostMatrix[requests[r].id,v]
                        bestVehicleForRequest = v
                    elseif insCostMatrix[requests[r].id,v] < secondBestInsertion
                        secondBestInsertion = insCostMatrix[requests[r].id,v]
                    end
                end
            end
            if bestVehicleForRequest == -1
                continue
            end
            if (secondBestInsertion - bestInsertion) > bestRegret
                bestRegret = secondBestInsertion - bestInsertion
                bestRequest = r
                overallBestVehicle = bestVehicleForRequest
            end
        end

        if bestRequest == -1
            break
        end

        # Find best insertion position
        status, pickUp, dropOff, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd  = findBestFeasibleInsertionRoute(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], scenario, visitedRoute=visitedRoute)

        # Update solution pre
        state.currentSolution.totalCost -= currentSolution.vehicleSchedules[overallBestVehicle].totalCost
        state.currentSolution.totalDistance -= currentSolution.vehicleSchedules[overallBestVehicle].totalDistance
        state.currentSolution.totalRideTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalTime
        state.currentSolution.totalIdleTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalIdleTime

        # Insert request
        insertRequest!(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], pickUp, dropOff, scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,totalCost = totalCost, totalDistance = totalDistance, totalIdleTime = totalIdleTime, totalTime = totalTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=waitingActivitiesToAdd)
        append!(state.assignedRequests, bestRequest)

        # Update solution pro
        state.nAssignedRequests += 1
        state.currentSolution.nTaxi -= 1
        state.currentSolution.totalCost -= scenario.taxiParameter
        state.currentSolution.totalCost += currentSolution.vehicleSchedules[overallBestVehicle].totalCost
        state.currentSolution.totalDistance += currentSolution.vehicleSchedules[overallBestVehicle].totalDistance
        state.currentSolution.totalRideTime += currentSolution.vehicleSchedules[overallBestVehicle].totalTime
        state.currentSolution.totalIdleTime += currentSolution.vehicleSchedules[overallBestVehicle].totalIdleTime

        # Remove request from requestBank
        setdiff!(requestBank,[bestRequest])

        # Recalculate insertion cost matrix
        reCalcCostMatrix!(overallBestVehicle, scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,visitedRoute)

    end


end

function fillInsertionCostMatrix!(scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},visitedRoute::Dict{Int, Dict{String, Int}})
    for r in requestBank
        for v in 1:length(scenario.vehicles)
            status, _, _, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(scenario.requests[r], currentSolution.vehicleSchedules[v], scenario,visitedRoute = visitedRoute)
            if status
                insCostMatrix[r,v] = bestCost - currentSolution.vehicleSchedules[v].totalCost
            else
                insCostMatrix[r,v] = typemax(Float64)
                compatibilityRequestVehicle[r,v] = false
            end
        end
    end
    
end

function reCalcCostMatrix!(v::Int,scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},visitedRoute::Dict{Int, Dict{String, Int}})
    for r in requestBank
        if compatibilityRequestVehicle[r,v]
            status, _, _, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(scenario.requests[r], currentSolution.vehicleSchedules[v], scenario,visitedRoute = visitedRoute)
            if status
                insCostMatrix[r,v] = bestCost - currentSolution.vehicleSchedules[v].totalCost
            else
                insCostMatrix[r,v] = typemax(Float64)
                compatibilityRequestVehicle[r,v] = false
            end
        end
    end

end


#== 
    Method that performs greedy insertion of requests
==#
function greedyInsertion(state::ALNSState,scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())
    #println("greedyInsertion: ", visitedRoute)

    @unpack currentSolution, requestBank = state
    newRequestBank = Int[]

        #TODO remove when stable also in other places
    if length(requestBank) != state.currentSolution.nTaxi
        println(requestBank)
        throw("Error: requestBank length does not match currentSolution.nTaxi")
        return
    end

    for r in requestBank
        request = scenario.requests[r]
        bestSchedule = VehicleSchedule()
        bestPickUp = -1
        bestDropOff = -1
        bestVehicle = -1
        bestNewStartOfServiceTimes = []
        bestNewEndOfServiceTimes = []
        bestWaitingActivitiesToDelete = []
        bestWaitingActivitiesToAdd = []
        bestCost = typemax(Float64)
        bestDistance = typemax(Float64)
        bestIdleTime = typemax(Int)
        bestTime = typemax(Int)

        for (idx,schedule) in enumerate(currentSolution.vehicleSchedules)
            status, pickUp, dropOff, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd = findBestFeasibleInsertionRoute(request, schedule, scenario, visitedRoute=visitedRoute)
            if status && totalCost < bestCost
                bestSchedule = schedule
                bestPickUp = pickUp
                bestDropOff = dropOff
                bestVehicle = idx
                bestNewStartOfServiceTimes = deepcopy(newStartOfServiceTimes)
                bestNewEndOfServiceTimes = deepcopy(newEndOfServiceTimes)
                bestWaitingActivitiesToDelete = deepcopy(waitingActivitiesToDelete)
                bestWaitingActivitiesToAdd = deepcopy(waitingActivitiesToAdd)
                bestCost = totalCost
                bestDistance = totalDistance
                bestIdleTime = totalIdleTime
                bestTime = totalTime
            end
        end

        # If a feasible insertion was found, insert the request
        if (bestVehicle != -1)

            # Update solution pre
            state.currentSolution.totalCost -= currentSolution.vehicleSchedules[bestVehicle].totalCost
            state.currentSolution.totalDistance -= currentSolution.vehicleSchedules[bestVehicle].totalDistance
            state.currentSolution.totalRideTime -= currentSolution.vehicleSchedules[bestVehicle].totalTime
            state.currentSolution.totalIdleTime -= currentSolution.vehicleSchedules[bestVehicle].totalIdleTime

            # Insert request
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, scenario,bestNewStartOfServiceTimes,bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete,totalCost = bestCost, totalDistance = bestDistance, totalIdleTime = bestIdleTime, totalTime = bestTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=bestWaitingActivitiesToAdd)
            append!(state.assignedRequests, r)

            # Update solution pro
            state.nAssignedRequests += 1
            state.currentSolution.nTaxi -= 1
            state.currentSolution.totalCost -= scenario.taxiParameter
            state.currentSolution.totalCost += currentSolution.vehicleSchedules[bestVehicle].totalCost
            state.currentSolution.totalDistance += currentSolution.vehicleSchedules[bestVehicle].totalDistance
            state.currentSolution.totalRideTime += currentSolution.vehicleSchedules[bestVehicle].totalTime
            state.currentSolution.totalIdleTime += currentSolution.vehicleSchedules[bestVehicle].totalIdleTime       
            
        else
            append!(newRequestBank, r)
        end
    end

    state.requestBank = newRequestBank

end


function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())
    bestPickUp = -1
    bestDropOff = -1
    bestNewStartOfServiceTimes = []
    bestNewEndOfServiceTimes = []
    bestWaitingActivitiesToDelete = [] 
    bestWaitingActivitiesToAdd = []  
    bestCost = typemax(Float64)
    bestDistance = typemax(Float64)
    bestIdleTime = typemax(Int)
    bestTime = typemax(Int)

    route = vehicleSchedule.route

    for i in 1:length(route)-1
        for j in i:length(route)-1
            feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario,visitedRoute=visitedRoute)

            if feasible
                if totalCost < bestCost
                    bestPickUp = i
                    bestDropOff = j
                    bestNewStartOfServiceTimes = deepcopy(newStartOfServiceTimes)
                    bestNewEndOfServiceTimes = deepcopy(newEndOfServiceTimes)
                    bestWaitingActivitiesToDelete = deepcopy(waitingActivitiesToDelete)
                    bestWaitingActivitiesToAdd = deepcopy(waitingActivitiesToAdd)
                    bestCost = totalCost
                    bestDistance = totalDistance
                    bestIdleTime = totalIdleTime
                    bestTime = totalTime
                end
            end
        end
    end

    return bestCost < typemax(Float64), bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd

end

end


