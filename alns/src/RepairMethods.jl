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

    #@timeit TO "RegretfillInsertionCostMatrix!" begin
        fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,visitedRoute,TO=TO)
    #end

    # Insert requests
    while !isempty(requestBank)
        bestRegret = typemin(Float64)
        bestRequest = -1
        overallBestVehicle = -1
        
        # Find best request and vehicle combination to insert
        #@timeit TO "RegretFindBestRequestVehicle" begin
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
        #end 

        if bestRequest == -1
            break
        end

        # Find best insertion position
        #@timeit TO "RegretFindBestFeasibleInsertion" begin
            status, pickUp, dropOff, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd  = findBestFeasibleInsertionRoute(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], scenario, visitedRoute=visitedRoute,TO=TO)
        #end

        # Update solution pre
        state.currentSolution.totalCost -= currentSolution.vehicleSchedules[overallBestVehicle].totalCost
        state.currentSolution.totalDistance -= currentSolution.vehicleSchedules[overallBestVehicle].totalDistance
        state.currentSolution.totalRideTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalTime
        state.currentSolution.totalIdleTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalIdleTime

        # Insert request
        #@timeit TO "RegretInsertRequest" begin
            insertRequest!(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], pickUp, dropOff, scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,totalCost = totalCost, totalDistance = totalDistance, totalIdleTime = totalIdleTime, totalTime = totalTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=waitingActivitiesToAdd)
            append!(state.assignedRequests, bestRequest)
        #end

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
        #@timeit TO "RegretreCalcCostMatrix!" begin
         reCalcCostMatrix!(overallBestVehicle, scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,visitedRoute,TO=TO)
        #end
    end


end

function fillInsertionCostMatrix!(scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},visitedRoute::Dict{Int, Dict{String, Int}};TO::TimerOutput=TimerOutput())
    
    vehicles = scenario.vehicles
    requests = scenario.requests
    vehicleSchedules = currentSolution.vehicleSchedules
    infVar = typemax(Float64)


    for r in requestBank
        request = requests[r]
        for v in eachindex(vehicles)
            schedule = vehicleSchedules[v]

            status, _, _, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario,visitedRoute = visitedRoute,TO=TO)
            if status
                insCostMatrix[r,v] = bestCost - schedule.totalCost
            else
                insCostMatrix[r,v] = infVar
                compatibilityRequestVehicle[r,v] = false
            end
        end
    end
    
end

function reCalcCostMatrix!(v::Int,scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},visitedRoute::Dict{Int, Dict{String, Int}};TO::TimerOutput=TimerOutput())
    requests = scenario.requests
    schedule = currentSolution.vehicleSchedules[v]
    infVar = typemax(Float64)

    for r in requestBank
        request = requests[r]
        if compatibilityRequestVehicle[r,v]
            status, _, _, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario,visitedRoute = visitedRoute,TO=TO)
            if status
                insCostMatrix[r,v] = bestCost - schedule.totalCost
            else
                insCostMatrix[r,v] = infVar
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
    @unpack requests, time, distance = scenario
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
    infVar = typemax(Float64)
    insertionCosts = Dict{Int64, Vector{Float64}}()
    for r in requestBank
        request = requests[r]
        insertionCosts[r] = ones(length(vehicleSchedules))*infVar

        for (idx,schedule) in enumerate(vehicleSchedules)
           # @timeit TO "GreedyFindFeasibleInsertion" begin
                status, _, _, _, _, _, totalCost, _, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario, visitedRoute=visitedRoute,TO=TO)
            #end

            # Save cost 
            if status
                insertionCosts[r][idx] = totalCost
            end
        end
    end

    # Loop through request bank and insert request with best cost 
    remainingRequests = copy(requestBank)
    for r in requestBank
        request = requests[r]
        popfirst!(remainingRequests)

        # Check if any feasible insertion was found
        costs = insertionCosts[r]
        if all(x -> x == infVar, costs)
            push!(newRequestBank, r)
            continue
        end

        # Extract best vehicle
        bestVehicle = argmin(costs)
        bestSchedule = vehicleSchedules[bestVehicle]
        #@timeit TO "GreedyFindFeasibleInsertion" begin
            status, bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd = findBestFeasibleInsertionRoute(request, bestSchedule, scenario, visitedRoute=visitedRoute,TO=TO)
        #end

        # Update solution pre
        state.currentSolution.totalCost -= bestSchedule.totalCost
        state.currentSolution.totalDistance -= bestSchedule.totalDistance
        state.currentSolution.totalRideTime -= bestSchedule.totalTime
        state.currentSolution.totalIdleTime -= bestSchedule.totalIdleTime

        # Insert request
        #@timeit TO "GreedyInsertRequest" begin
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, scenario,bestNewStartOfServiceTimes,bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete,totalCost = bestCost, totalDistance = bestDistance, totalIdleTime = bestIdleTime, totalTime = bestTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=bestWaitingActivitiesToAdd)
            append!(state.assignedRequests, r)
        #end

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
           # @timeit TO "GreedyFindFeasibleInsertion" begin
                status, _, _, _, _, _, totalCost, _, _, _, _ = findBestFeasibleInsertionRoute(request2, bestSchedule, scenario, visitedRoute=visitedRoute,TO=TO)
           # end

            # Save cost 
            if status
                insertionCosts[r2][bestVehicle] = totalCost
            else
                insertionCosts[r2][bestVehicle] = infVar
            end
        end
      
    end

    state.requestBank = newRequestBank

end


function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(), TO::TimerOutput=TimerOutput())
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

    # Initialize arrays  
    arraySize = length(route) + 2
    newStartOfServiceTimes = zeros(Int, arraySize)
    newEndOfServiceTimes = zeros(Int, arraySize)
    waitingActivitiesToDelete = zeros(Int, 0)
    waitingActivitiesToAdd = zeros(Int, 0)
    visitedRouteIds = Set(keys(visitedRoute))

    for i in 1:length(route)-1
        for j in i:length(route)-1
            # feasible, _, _,_, totalCost, totalDistance, totalIdleTime, totalTime, _  = @timeit TO "checkFeasibilityOfInsertionAtPosition" begin 
            #     checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario,visitedRoute=visitedRoute,TO=TO,
            #     newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)
            # end

            feasible, _, _,_, totalCost, totalDistance, totalIdleTime, totalTime, _  = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario,visitedRoute=visitedRoute,TO=TO,
            newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)

            #@timeit TO "checkFeasibilityOfInsertionAtPositionCOPY" begin 
                if feasible && (totalCost < bestCost)
                        bestPickUp = i
                        bestDropOff = j
                        # bestNewStartOfServiceTimes = copy(newStartOfServiceTimes)
                        # bestNewEndOfServiceTimes = copy(newEndOfServiceTimes)
                        # bestWaitingActivitiesToDelete = copy(waitingActivitiesToDelete)
                        # bestWaitingActivitiesToAdd = copy(waitingActivitiesToAdd)
                        # bestCost = totalCost
                        # bestDistance = totalDistance
                        # bestIdleTime = totalIdleTime
                        # bestTime = totalTime
                end
            #end
        end
    end

    # Because copy is slowes
    if bestPickUp != -1
        feasible, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd =    checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,bestPickUp,bestDropOff,scenario,visitedRoute=visitedRoute,TO=TO,
        newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)
    end

    return bestCost < typemax(Float64), bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd

end

end


