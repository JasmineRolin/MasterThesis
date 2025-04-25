module RepairMethods 

using utils, UnPack, domain, TimerOutputs, Random
using ..ALNSDomain
using Base.Threads

export greedyInsertion
export regretInsertion

const EMPTY_RESULT = (false, -1, -1, Vector{Int}(), Vector{Int}(), Vector{Int}(), typemax(Float64), typemax(Float64), typemax(Int), typemax(Int), Vector{Int}())

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

    # Keep track of insertion costs for each request and vehicle
    insCostMatrix = zeros(Float64, length(requests), length(scenario.vehicles))

    # Keep track of compatibility of requests and vehicles
    compatibilityRequestVehicle = ones(Bool, length(requests), length(scenario.vehicles))

    # Keep track of the best position to insert each request in each vehicle
    positions = Array{Tuple{Int64, Int64}, 2}(undef, length(requests), length(scenario.vehicles))

    @timeit TO "RegretfillInsertionCostMatrix!" begin
        fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,positions,visitedRoute)
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

        bestSchedule = currentSolution.vehicleSchedules[overallBestVehicle]
        # Find best insertion position
        @timeit TO "RegretFindBestFeasibleInsertionACTUAL" begin
           # status, pickUp, dropOff, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd  = findBestFeasibleInsertionRoute(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], scenario, visitedRoute=visitedRoute,TO=TO)
            
            arraySize = length(bestSchedule.route) + 2
            newStartOfServiceTimes = zeros(Int, arraySize)
            newEndOfServiceTimes = zeros(Int, arraySize)
            waitingActivitiesToDelete = zeros(Int, 0)
            waitingActivitiesToAdd = zeros(Int, 0)
            visitedRouteIds = Set(keys(visitedRoute))
            pickUp, dropOff = positions[bestRequest,overallBestVehicle]

            feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd = checkFeasibilityOfInsertionAtPosition(requests[bestRequest],bestSchedule,pickUp,dropOff,scenario,visitedRoute=visitedRoute,TO=TO,
            newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)
        
        end

        # Update solution pre
        state.currentSolution.totalCost -= bestSchedule.totalCost
        state.currentSolution.totalDistance -= bestSchedule.totalDistance
        state.currentSolution.totalRideTime -= bestSchedule.totalTime
        state.currentSolution.totalIdleTime -= bestSchedule.totalIdleTime

        # Insert request
        @timeit TO "RegretInsertRequest" begin
            insertRequest!(requests[bestRequest], bestSchedule, pickUp, dropOff, scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,totalCost = totalCost, totalDistance = totalDistance, totalIdleTime = totalIdleTime, totalTime = totalTime,visitedRoute=visitedRoute, waitingActivitiesToAdd=waitingActivitiesToAdd)
            append!(state.assignedRequests, bestRequest)
        end

        # Update solution pro
        state.nAssignedRequests += 1
        state.currentSolution.nTaxi -= 1
        state.currentSolution.totalCost -= scenario.taxiParameter
        state.currentSolution.totalCost += bestSchedule.totalCost
        state.currentSolution.totalDistance += bestSchedule.totalDistance
        state.currentSolution.totalRideTime += bestSchedule.totalTime
        state.currentSolution.totalIdleTime += bestSchedule.totalIdleTime

        # Remove request from requestBank
        setdiff!(requestBank,[bestRequest])

        # Recalculate insertion cost matrix
        @timeit TO "RegretreCalcCostMatrix!" begin
            reCalcCostMatrix!(overallBestVehicle, scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,positions,visitedRoute)
        end
    end


end

# function fillInsertionCostMatrix!(scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},positions::Dict{Tuple{Int64,Int64}, Tuple{Int64,Int64}},visitedRoute::Dict{Int, Dict{String, Int}};TO::TimerOutput=TimerOutput())
    
#     vehicles = scenario.vehicles
#     requests = scenario.requests
#     vehicleSchedules = currentSolution.vehicleSchedules
#     infVar = typemax(Float64)


#     for r in requestBank
#         request = requests[r]
#         for v in eachindex(vehicles)
#             schedule = vehicleSchedules[v]

#             @timeit TO "RegretFindFeasibleInsertionROUTE" begin
#                 status, bestPickUp, bestDropOff, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario,visitedRoute = visitedRoute,TO=TO)
#             end

#             if status
#                 insCostMatrix[r,v] = bestCost - schedule.totalCost
#                 positions[(r,v)] = (bestPickUp, bestDropOff)
#             else
#                 insCostMatrix[r,v] = infVar
#                 compatibilityRequestVehicle[r,v] = false
#             end
#         end
#     end
    
# end

function fillInsertionCostMatrix!(
    scenario::Scenario,
    currentSolution::Solution,
    requestBank::Vector{Int}, 
    insCostMatrix::Array{Float64,2},
    compatibilityRequestVehicle::Array{Bool,2},
    positions::Array{Tuple{Int64, Int64}, 2},  # Change positions type to 2D array of tuples
    visitedRoute::Dict{Int, Dict{String, Int}}
)
    vehicles = scenario.vehicles
    requests = scenario.requests
    vehicleSchedules = currentSolution.vehicleSchedules
    infVar = typemax(Float64)

    n_threads = Threads.nthreads()

    # Thread-local buffers (one per thread)
    local_positions = [fill((-1, -1), size(positions)) for _ in 1:n_threads]  # Initializing with (-1, -1)
    local_costs = [fill(infVar, size(insCostMatrix)) for _ in 1:n_threads]
    local_compatibility = [trues(size(insCostMatrix)) for _ in 1:n_threads]

    Threads.@threads for idx in 1:length(requestBank)
        r = requestBank[idx]
        request = requests[r]
        thread_id = Threads.threadid()

        pos_buffer = local_positions[thread_id]
        cost_buffer = local_costs[thread_id]
        compat_buffer = local_compatibility[thread_id]

        for v in eachindex(vehicles)
            schedule = vehicleSchedules[v]
            scheduleTotalCost = schedule.totalCost

            # Check if insertion is feasible 
            status, bestPickUp, bestDropOff, _, _, _, bestCost, _, _, _ = findBestFeasibleInsertionRoute(
                request, schedule, scenario, visitedRoute=visitedRoute
            )

            if status
                cost_buffer[r, v] = bestCost  #- scheduleTotalCost
                pos_buffer[r, v] = (bestPickUp, bestDropOff)
            else
                cost_buffer[r, v] = infVar
                compat_buffer[r, v] = false
            end
        end
    end

    # Merge thread-local results into shared outputs
    for t in 1:n_threads
        for r in 1:size(local_positions[t], 1)
            for v in 1:size(local_positions[t], 2)
                insCostMatrix[r, v] = local_costs[t][r, v]
                positions[r, v] = local_positions[t][r, v]
                compatibilityRequestVehicle[r, v] = local_compatibility[t][r, v]
            end
        end
    end
end



function reCalcCostMatrix!(v::Int,scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2},positions::Array{Tuple{Int64, Int64}, 2},visitedRoute::Dict{Int, Dict{String, Int}};TO::TimerOutput=TimerOutput())
    requests = scenario.requests
    schedule = currentSolution.vehicleSchedules[v]
    infVar = typemax(Float64)

    for r in requestBank
        request = requests[r]
        if compatibilityRequestVehicle[r,v]
            status, bestPickUp, bestDropOff, _, _,_, bestCost, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario,visitedRoute = visitedRoute,TO=TO)
            if status
                insCostMatrix[r,v] = bestCost #- schedule.totalCost
                positions[r,v] = (bestPickUp, bestDropOff)
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
    nRequests = length(requests)
    nVehicles = length(vehicleSchedules)
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
  
    # for r in requestBank
    #     request = requests[r]
    #     insertionCosts[r] = ones(length(vehicleSchedules))*infVar

    #     for (idx,schedule) in enumerate(vehicleSchedules)
    #         @timeit TO "GreedyFindFeasibleInsertion" begin
    #             status, bestPickUp, bestDropOff, _, _, _, totalCost, _, _, _, _ = findBestFeasibleInsertionRoute(request, schedule, scenario, visitedRoute=visitedRoute,TO=TO)
    #         end

    #         # Save cost 
    #         if status
    #             insertionCosts[r][idx] = totalCost
    #             positions[(r,idx)] = (bestPickUp, bestDropOff)
    #         end
    #     end
    # end

    # Keep track of insertion costs for each request and vehicle
    insCostMatrix = zeros(Float64, length(requests), length(scenario.vehicles))

    # Keep track of compatibility of requests and vehicles
    compatibilityRequestVehicle = ones(Bool, length(requests), length(scenario.vehicles))

    # Keep track of the best position to insert each request in each vehicle
    positions = Array{Tuple{Int64, Int64}, 2}(undef, length(requests), length(scenario.vehicles))

    @timeit TO "GreedyFillInsertionCostMatrix!" begin
        fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle,positions,visitedRoute)
    end

    # Loop through request bank and insert request with best cost 
    remainingRequests = copy(requestBank)
    for r in requestBank
        request = requests[r]
        popfirst!(remainingRequests)

        # Check if any feasible insertion was found
        costs = insCostMatrix[r,:]
        if all(x -> x == infVar, costs)
            push!(newRequestBank, r)
            continue
        end

        # Extract best vehicle
        bestVehicle = argmin(costs)
       # println(findmin(costs))
        bestSchedule = vehicleSchedules[bestVehicle]

        @timeit TO "GreedyFindFeasibleInsertionACTUAL" begin
           # status, bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd = findBestFeasibleInsertionRoute(request, bestSchedule, scenario, visitedRoute=visitedRoute,TO=TO)
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
            try 
                feasible, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd = checkFeasibilityOfInsertionAtPosition(request,bestSchedule,bestPickUp,bestDropOff,scenario,visitedRoute=visitedRoute,TO=TO,
            newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)
            catch e 
                println("Error in checkFeasibilityOfInsertionAtPosition")
                println("Request: ", request)
                println("Best Schedule: ", bestSchedule)
                println("Best PickUp: ", bestPickUp)
                println("Best DropOff: ", bestDropOff)
                println(findmin(costs))
                println( positions[(r,bestVehicle)])
                println(positions)

                throw(e)
            end
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
        # for r2 in remainingRequests
        #     request2 = scenario.requests[r2]
        #     @timeit TO "GreedyFindFeasibleInsertion" begin
        #         status, bestPickUp, bestDropOff, _, _, _, totalCost, _, _, _, _ = findBestFeasibleInsertionRoute(request2, bestSchedule, scenario, visitedRoute=visitedRoute,TO=TO)
        #    end

        #     # Save cost 
        #     if status
        #         insCostMatrix[r2,bestVehicle] = totalCost
        #         positions[r2,bestVehicle] = (bestPickUp, bestDropOff)
        #     else
        #         insCostMatrix[r2,bestVehicle] = infVar
        #     end
        # end

        # Recalculate insertion cost matrix
        @timeit TO "GreedyReCalcCostMatrix!" begin
            reCalcCostMatrix!(bestVehicle, scenario, currentSolution, remainingRequests, insCostMatrix, compatibilityRequestVehicle,positions,visitedRoute)
        end
      
    end

    state.requestBank = newRequestBank

end


function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(), TO::TimerOutput=TimerOutput())
    bestPickUp = -1
    bestDropOff = -1
    bestCost = typemax(Float64)

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
            feasible, _, _,_, totalCost, totalDistance, totalIdleTime, totalTime, _  = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario,visitedRoute=visitedRoute,
            newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)

            if feasible && (totalCost < bestCost)
                    bestPickUp = i
                    bestDropOff = j
                    bestCost = totalCost
            end
        end
    end


    feasible = (bestPickUp != -1 && bestDropOff != -1 && bestCost < typemax(Float64))

    # Because copy is slowes
    if feasible
       feasible, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd =    checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,bestPickUp,bestDropOff,scenario,visitedRoute=visitedRoute,TO=TO,
       newStartOfServiceTimes=newStartOfServiceTimes,newEndOfServiceTimes=newEndOfServiceTimes,waitingActivitiesToDelete=waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd,visitedRouteIds=visitedRouteIds)

       return true, bestPickUp, bestDropOff, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes,bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd
    else 
        return EMPTY_RESULT
    end
end

end


