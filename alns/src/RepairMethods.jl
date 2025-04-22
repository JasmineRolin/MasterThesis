module RepairMethods 

using utils, UnPack, domain, TimerOutputs, Random
using ..ALNSDomain

export greedyInsertion
export regretInsertion

#== 
    Method that performs regret insertion of requests
==#
function regretInsertion(state::ALNSState,scenario::Scenario;visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())
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

    @timeit TO "RegretfillInsertionCostMatrix!" begin
        fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,visitedRoute)
    end

    # Insert requests
    while !isempty(requestBank)
        bestRegret = typemin(Float64)
        bestRequest = -1
        overallBestVehicle = -1
        
        # Find best request and vehicle combination to insert
        @timeit TO "RegretFindBestRequestVehicle" begin
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
        end 

        if bestRequest == -1
            break
        end

        # Find best insertion position
        @timeit TO "RegretFindBestFeasibleInsertion" begin
            status, pickUp, dropOff, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd  = findBestFeasibleInsertionRoute(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], scenario, visitedRoute=visitedRoute)
        end
        # Update solution pre
        state.currentSolution.totalCost -= currentSolution.vehicleSchedules[overallBestVehicle].totalCost
        state.currentSolution.totalDistance -= currentSolution.vehicleSchedules[overallBestVehicle].totalDistance
        state.currentSolution.totalRideTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalTime
        state.currentSolution.totalIdleTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalIdleTime

        # Insert request
        @timeit TO "RegretInsertRequest" begin
            insertRequest!(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], pickUp, dropOff, scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,totalCost = totalCost, totalDistance = totalDistance, totalIdleTime = totalIdleTime, totalTime = totalTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=waitingActivitiesToAdd)
            append!(state.assignedRequests, bestRequest)
        end

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
        @timeit TO "RegretreCalcCostMatrix!" begin
         reCalcCostMatrix!(overallBestVehicle, scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,visitedRoute)
        end
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
function greedyInsertion(state::ALNSState,scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())
    #println("greedyInsertion: ", visitedRoute)

    @unpack currentSolution, requestBank = state
    @unpack vehicleSchedules = currentSolution
    newRequestBank = Int[]

    #TODO remove when stable also in other places
    if length(requestBank) != state.currentSolution.nTaxi
        println(requestBank)
        throw("Error: requestBank length does not match currentSolution.nTaxi")
        return
    end

    # Shuffle request bank
    shuffle!(requestBank) 

    # Keep track of costs 
    insertionCosts = Dict{Int64, Vector{Float64}}()
    for r in requestBank
        request = scenario.requests[r]
        insertionCosts[r] = ones(length(vehicleSchedules))*typemax(Float64)

        for (idx,schedule) in enumerate(vehicleSchedules)
            @timeit TO "GreedyFindFeasibleInsertion" begin
                status, _, _, _, _, _, totalCost, _, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario, visitedRoute=visitedRoute)
            end

            # Save cost 
            if status
                insertionCosts[r][idx] = totalCost
            end
        end
    end

    # Loop through request bank and insert request with best cost 
    remainingRequests = copy(requestBank)
    for r in requestBank
        request = scenario.requests[r]
        popfirst!(remainingRequests)

        # Check if any feasible insertion was found
        if all(insertionCosts[r] .== typemax(Float64))
            push!(newRequestBank, r)
            continue
        end

        # Extract best vehicle
        bestVehicle = argmin(insertionCosts[r])
        bestSchedule = vehicleSchedules[bestVehicle]
        @timeit TO "GreedyFindFeasibleInsertion" begin
            status, bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd = findBestFeasibleInsertionRoute(request, bestSchedule, scenario, visitedRoute=visitedRoute)
        end

        # Update solution pre
        state.currentSolution.totalCost -= bestSchedule.totalCost
        state.currentSolution.totalDistance -= bestSchedule.totalDistance
        state.currentSolution.totalRideTime -= bestSchedule.totalTime
        state.currentSolution.totalIdleTime -= bestSchedule.totalIdleTime

        # Insert request
        @timeit TO "GreedyInsertRequest" begin
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, scenario,bestNewStartOfServiceTimes,bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete,totalCost = bestCost, totalDistance = bestDistance, totalIdleTime = bestIdleTime, totalTime = bestTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=bestWaitingActivitiesToAdd)
            append!(state.assignedRequests, r)
        end

        # Update solution pro
        state.nAssignedRequests += 1
        state.currentSolution.nTaxi -= 1
        state.currentSolution.totalCost -= scenario.taxiParameter
        state.currentSolution.totalCost += bestSchedule.totalCost
        state.currentSolution.totalDistance += bestSchedule.totalDistance
        state.currentSolution.totalRideTime += bestSchedule.totalTime
        state.currentSolution.totalIdleTime += bestSchedule.totalIdleTime   
        
        # Update costs for route 
        for r2 in remainingRequests
            request2 = scenario.requests[r2]
            @timeit TO "GreedyFindFeasibleInsertion" begin
                status, _, _, _, _, _, totalCost, _, _, _, _ = findBestFeasibleInsertionRoute(request2, bestSchedule, scenario, visitedRoute=visitedRoute)
            end

            # Save cost 
            if status
                insertionCosts[r2][bestVehicle] = totalCost
            else
                insertionCosts[r2][bestVehicle] = typemax(Float64)
            end
        end
      
    end

    state.requestBank = newRequestBank

end


function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())
    bestPickUp = -1
    bestDropOff = -1
    bestNewStartOfServiceTimes = Vector{Int}()
    bestNewEndOfServiceTimes = Vector{Int}()
    bestWaitingActivitiesToDelete = Vector{Int}() 
    bestWaitingActivitiesToAdd = Vector{Int}()
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
                    bestNewStartOfServiceTimes = copy(newStartOfServiceTimes)
                    bestNewEndOfServiceTimes = copy(newEndOfServiceTimes)
                    bestWaitingActivitiesToDelete = copy(waitingActivitiesToDelete)
                    bestWaitingActivitiesToAdd = copy(waitingActivitiesToAdd)
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


