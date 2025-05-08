module RepairMethods 

using utils, UnPack, domain, TimerOutputs, Random
using ..ALNSDomain
using Base.Threads

export greedyInsertion
export regretInsertion

const EMPTY_RESULT = (false, -1, -1, Vector{Int}(), Vector{Int}(), Vector{Int}(), typemax(Float64), typemax(Float64), typemax(Int), typemax(Int), Vector{Int}())

# TODO: delete 
global countTotal = Ref(0)
global countFeasible = Ref(0)

#== 
    Method that performs regret insertion of requests
==#
function regretInsertion(state::ALNSState,scenario::Scenario;visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())
    countTotal[] = 0
    countFeasible[] = 0

    # TODO: should we implement noise?
    @unpack currentSolution, requestBank = state
    requests = scenario.requests
    vehicleSchedules = currentSolution.vehicleSchedules
    nRequests = length(requests)
    nVehicles = length(vehicleSchedules)

    # TODO: remove when stable also in other places
    if length(requestBank) != state.currentSolution.nTaxi
        println(requestBank)
        throw("Error: requestBank length does not match currentSolution.nTaxi")
        return
    end

    # Define insertion matrix
    insertionCosts = zeros(Float64, nRequests, nVehicles)
    compatibilityRequestVehicle = ones(Bool, nRequests, nVehicles)
    positions = [(-1, -1) for _ in 1:nRequests, _ in 1:nVehicles]

    # Fill insertion cost matrix
    @timeit TO "RegretfillInsertionCostMatrix!" begin
        fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insertionCosts, compatibilityRequestVehicle,positions,visitedRoute,TO=TO)
    end

    # Insert requests
    while !isempty(requestBank)
        bestRegret = typemin(Float64)
        bestRequest = -1
        overallBestVehicle = -1
        
        # Find best request and vehicle combination to insert
        @timeit TO "GreedyFindFeasibleInsertionAndInsert" begin
            for r in requestBank
                request = requests[r]
                bestVehicleForRequest = -1
                bestInsertion = secondBestInsertion = typemax(Float64)

                for v in 1:nVehicles
                    if compatibilityRequestVehicle[r,v]
                        if insertionCosts[r,v] < bestInsertion
                            secondBestInsertion = bestInsertion
                            bestInsertion = insertionCosts[r,v]
                            bestVehicleForRequest = v
                        elseif insertionCosts[r,v] < secondBestInsertion
                            secondBestInsertion = insertionCosts[r,v]
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
        
            # Break if no request can be inserted
            if bestRequest == -1
                break
            end

            # Retrieve best schedule
            bestSchedule = vehicleSchedules[overallBestVehicle]

            # Initialize arrays 
            arraySize = length(bestSchedule.route) + 2
            newStartOfServiceTimes = zeros(Int, arraySize)
            newEndOfServiceTimes = zeros(Int, arraySize)
            waitingActivitiesToDelete = zeros(Int, 0)
            waitingActivitiesToAdd = zeros(Int, 0)
            visitedRouteIds = Set(keys(visitedRoute))
            pickUp, dropOff = positions[bestRequest,overallBestVehicle]

            # Find best insertion position
            feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd = checkFeasibilityOfInsertionAtPosition(requests[bestRequest],bestSchedule,pickUp,dropOff,scenario,visitedRoute=visitedRoute,TO=TO,
                                                                                                                                                                                                                newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,
                                                                                                                                                                                                                waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)
            
            # Update solution pre
            state.currentSolution.totalCost -= bestSchedule.totalCost
            state.currentSolution.totalDistance -= bestSchedule.totalDistance
            state.currentSolution.totalRideTime -= bestSchedule.totalTime
            state.currentSolution.totalIdleTime -= bestSchedule.totalIdleTime

            # Insert request
            insertRequest!(requests[bestRequest], bestSchedule, pickUp, dropOff, scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,totalCost = totalCost, totalDistance = totalDistance, totalIdleTime = totalIdleTime, totalTime = totalTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=waitingActivitiesToAdd)
            append!(state.assignedRequests, bestRequest)
            
            # Update solution pro
            state.nAssignedRequests += 1
            state.currentSolution.nTaxi -= 1
            state.currentSolution.totalCost -= scenario.taxiParameter
            state.currentSolution.totalCost += bestSchedule.totalCost
            state.currentSolution.totalDistance += bestSchedule.totalDistance
            state.currentSolution.totalRideTime += bestSchedule.totalTime
            state.currentSolution.totalIdleTime += bestSchedule.totalIdleTime
        end

        # Remove request from requestBank
        setdiff!(requestBank,[bestRequest])

        # Recalculate insertion cost matrix
        @timeit TO "RegretreCalculateInsertionCostMatrix!!" begin
            reCalculateInsertionCostMatrix!!(overallBestVehicle, scenario, currentSolution, requestBank, insertionCosts, compatibilityRequestVehicle,positions,visitedRoute,TO=TO)
        end
    end

    # TODO: delete 
    # println("REGRET: TOTAL: ", countTotal[], " FEASIBLE: ", countFeasible[])
end


#== 
    Method that performs greedy insertion of requests
==#
function greedyInsertion(state::ALNSState,scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())
    countTotal[] = 0
    countFeasible[] = 0

    @unpack currentSolution, requestBank = state
    @unpack vehicleSchedules = currentSolution
    @unpack requests, time, distance = scenario
    newRequestBank = Int[]
    infVar = typemax(Float64)
    nRequests = length(requests)
    nVehicles = length(vehicleSchedules)
    nRequestBank = length(requestBank)

    # TODO: remove when stable also in other places
    if length(requestBank) != state.currentSolution.nTaxi
        println(requestBank)
        throw("Error: requestBank length does not match currentSolution.nTaxi")
        return
    end

    # Shuffle request bank
    shuffle!(requestBank) 

    
    # Define insertion matrix
    insertionCosts = zeros(Float64, nRequests, nVehicles)
    compatibilityRequestVehicle = ones(Bool, nRequests,nVehicles)
    positions = [(-1, -1) for _ in 1:nRequests, _ in 1:nVehicles]

    # Fill insertion cost matrix
    @timeit TO "GreedyfillInsertionCostMatrix!" begin
        fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insertionCosts, compatibilityRequestVehicle,positions,visitedRoute,TO=TO)
    end


    # Loop through request bank and insert request with lowest insertion cost 
    for (idx,r) in enumerate(requestBank)
        request = requests[r]

        # Check if any feasible insertion was found
        costs = insertionCosts[r,:]
        if all(x -> x == infVar, costs)
            push!(newRequestBank, r)
            continue
        end

        # Extract best vehicle
        bestVehicle = argmin(costs)
        bestSchedule = vehicleSchedules[bestVehicle]

        @timeit TO "GreedyFindFeasibleInsertionAndInsert" begin
            arraySize = length(bestSchedule.route) + 2
            newStartOfServiceTimes = zeros(Int, arraySize)
            newEndOfServiceTimes = zeros(Int, arraySize)
            waitingActivitiesToDelete = zeros(Int, 0)
            waitingActivitiesToAdd = zeros(Int, 0)
            visitedRouteIds = Set(keys(visitedRoute))
            bestPickUp = bestDropOff = -1
            try
                bestPickUp, bestDropOff = positions[r,bestVehicle]
            catch e 
                println(costs)
                throw(e)
            end

            feasible = true 
            bestNewStartOfServiceTimes, bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete,bestWaitingActivitiesToAdd = Vector{Int}(),Vector{Int}(),Vector{Int}(), Vector{Int}()
            bestCost, bestDistance, bestIdleTime, bestTime = 0.0,0.0,0.0,0.0

            # Find needed information 
                feasible, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd = checkFeasibilityOfInsertionAtPosition(request,bestSchedule,bestPickUp,bestDropOff,scenario,visitedRoute=visitedRoute,TO=TO,
            newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)

             # Update solution pre
            state.currentSolution.totalCost -= bestSchedule.totalCost
            state.currentSolution.totalDistance -= bestSchedule.totalDistance
            state.currentSolution.totalRideTime -= bestSchedule.totalTime
            state.currentSolution.totalIdleTime -= bestSchedule.totalIdleTime

            # Insert request
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, scenario,bestNewStartOfServiceTimes,bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete,totalCost = bestCost, totalDistance = bestDistance, totalIdleTime = bestIdleTime, totalTime = bestTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=bestWaitingActivitiesToAdd)
            append!(state.assignedRequests, r)

             # Update solution pro
            state.nAssignedRequests += 1
            state.currentSolution.nTaxi -= 1
            state.currentSolution.totalCost -= scenario.taxiParameter
            state.currentSolution.totalCost += bestSchedule.totalCost
            state.currentSolution.totalDistance += bestSchedule.totalDistance
            state.currentSolution.totalRideTime += bestSchedule.totalTime
            state.currentSolution.totalIdleTime += bestSchedule.totalIdleTime 
        end

        # Recalculate insertion costs for vehicle 
        @timeit TO "GreedyreCalculateInsertionCostMatrix!!" begin
            if idx != nRequestBank
                reCalculateInsertionCostMatrix!!(bestVehicle, scenario, currentSolution, requestBank[idx+1:end], insertionCosts, compatibilityRequestVehicle,positions,visitedRoute,TO=TO)
            end
        end
      
    end

    state.requestBank = newRequestBank

    # TODO: delete 
   # println("GREEDY: TOTAL: ", countTotal[], " FEASIBLE: ", countFeasible[])

end




function fillInsertionCostMatrix!(scenario::Scenario,currentSolution::Solution,requestBank::Vector{Int}, insertionCosts::Array{Float64,2},compatibilityRequestVehicle::Array{Bool,2},positions::Array{Tuple{Int,Int}, 2},visitedRoute::Dict{Int, Dict{String, Int}}; TO::TimerOutput=TimerOutput())
    requests = scenario.requests
    vehicleSchedules = currentSolution.vehicleSchedules
    infVar = typemax(Float64)

    for idx in 1:length(requestBank)
        r = requestBank[idx]
        request = requests[r]
    
        for v in eachindex(vehicleSchedules)
            schedule = vehicleSchedules[v]

            status, bestPickUp, bestDropOff, _, _, _, bestCost, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario, visitedRoute=visitedRoute, TO=TO)

            if status
                insertionCosts[r, v] = bestCost - schedule.totalCost
                positions[r, v] = (bestPickUp, bestDropOff)
            else
                insertionCosts[r, v] = infVar
                compatibilityRequestVehicle[r, v] = false
            end
        end
    end
end


#==
 Method to recalculate insertion costs for requests and specific vehicle
==#
function reCalculateInsertionCostMatrix!!(v::Int,scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insertionCosts::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},positions::Array{Tuple{Int64,Int64}, 2},visitedRoute::Dict{Int, Dict{String, Int}};TO::TimerOutput=TimerOutput())
    requests = scenario.requests
    schedule = currentSolution.vehicleSchedules[v]
    scheduleTotalCost = schedule.totalCost
    infVar = typemax(Float64)

    for r in requestBank
        request = requests[r]
        if compatibilityRequestVehicle[r,v]
            status, bestPickUp, bestDropOff, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario,visitedRoute = visitedRoute,TO=TO)
            if status
                insertionCosts[r,v] = bestCost - scheduleTotalCost
                positions[r,v] = (bestPickUp, bestDropOff)
            else
                insertionCosts[r,v] = infVar
                compatibilityRequestVehicle[r,v] = false
            end
        end
    end

end

#== 
    Method to find the best feasible insertion route for a request
==# 
function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(), TO::TimerOutput=TimerOutput())
    bestPickUp = -1
    bestDropOff = -1
    bestCost = typemax(Float64)
    route = vehicleSchedule.route

    @unpack vehicle = vehicleSchedule

    # Initialize arrays to reuse in checkFeasibilityOfInsertionAtPosition
    # TODO: is this actually better than copying newStartOfServiceTimes etc in loop ?
    arraySize = length(route) + 2
    newStartOfServiceTimes = zeros(Int, arraySize)
    newEndOfServiceTimes = zeros(Int, arraySize)
    waitingActivitiesToDelete = zeros(Int, 0)
    waitingActivitiesToAdd = zeros(Int, 0)
    visitedRouteIds = Set(keys(visitedRoute))

    # Check that vehicle window fits request window
    pickUpActivity = request.pickUpActivity
    dropOffActivity = request.dropOffActivity
    if vehicle.availableTimeWindow.startTime > pickUpActivity.timeWindow.endTime || vehicle.availableTimeWindow.endTime < dropOffActivity.timeWindow.startTime
        return EMPTY_RESULT
    end

    printval = false
    # if request.id == 20 && vehicleSchedule.vehicle.id == 2
    #   printRouteHorizontal(vehicleSchedule)
    #   printval = true
    # end

    # Loop through each position in route 
    break_PICKUP = false
    break_DROPOFF = false
    min_j_to_consider = length(route) - 1
    for i in 1:length(route)-1
        for j in i:min_j_to_consider
            countTotal[] += 1

            if printval
                println("i = ",i," j = ",j)
            end

            # Check if position is feasible
            feasible, _, _,_, totalCost, _, _, _, _, break_PICKUP, break_DROPOFF, break_DROPOFF_update_J  = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario,visitedRoute=visitedRoute,
                                                                                            newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,
                                                                                            waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds,TO=TO)

                                                                                            
             if printval 
                println("feasible = ",feasible)
                println("break_PICKUP = ",break_PICKUP)
                println("break_DROPOFF = ",break_DROPOFF)
                println("break_DROPOFF_update_J = ",break_DROPOFF_update_J)
             end

            # Update best position if feasible                                                                           
            if feasible && (totalCost < bestCost)
                bestPickUp = i
                bestDropOff = j
                bestCost = totalCost

                countFeasible[] += 1
            end

            if break_DROPOFF_update_J
                min_j_to_consider = min(min_j_to_consider, j - 1)  # Skip j and all greater in future
                break
            elseif break_DROPOFF
                break
            end
        end

        if break_PICKUP
            break
        end

    end

    # Return if feasible position is found 
    feasible = (bestPickUp != -1 && bestDropOff != -1 && bestCost < typemax(Float64))

    if printval
        println("bestPickUp = ",bestPickUp)
        println("bestDropOff = ",bestDropOff)
        println("bestCost = ",bestCost)
    end

    # TODO: is this actually better than copying newStartOfServiceTimes etc in loop ? 
    if feasible
       feasible, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd =    checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,bestPickUp,bestDropOff,scenario,visitedRoute=visitedRoute,TO=TO,
       newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)

       return true, bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd
    else 
        return EMPTY_RESULT
    end

end

end


