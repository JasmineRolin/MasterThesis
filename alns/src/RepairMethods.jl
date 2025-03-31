module RepairMethods 

using utils, UnPack, domain
using ..ALNSDomain

export greedyInsertion
export regretInsertion

#== 
    Method that performs regret insertion of requests
==#
function regretInsertion(state::ALNSState,scenario::Scenario)
    #TODO should we implement noise?
    @unpack destroyWeights, repairWeights, destroyNumberOfUses, repairNumberOfUses, bestSolution, currentSolution, requestBank = state
    requests = scenario.requests

    # Define insertion matrix
    insCostMatrix = zeros(Float64, length(requests), length(scenario.vehicles))
    compatibilityRequestVehicle = ones(Bool, length(requests), length(scenario.vehicles))
    fillInsertionCostMatrix!(scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle)

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
        status, delta, pickUp, dropOff = findBestFeasibleInsertionRoute(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], scenario)

        # Update solution pre
        state.currentSolution.totalCost -= currentSolution.vehicleSchedules[overallBestVehicle].totalCost
        state.currentSolution.totalDistance -= currentSolution.vehicleSchedules[overallBestVehicle].totalDistance
        state.currentSolution.totalRideTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalTime
        state.currentSolution.totalIdleTime -= currentSolution.vehicleSchedules[overallBestVehicle].totalIdleTime

        # Insert request
        insertRequest!(requests[bestRequest], currentSolution.vehicleSchedules[overallBestVehicle], pickUp, dropOff, scenario)
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
        println("HERE!!!!!!!!")
        println(bestRequest)
        println(requestBank)
        setdiff!(requestBank,[bestRequest])
        println(requestBank)

        # Recalculate insertion cost matrix
        reCalcCostMatrix!(overallBestVehicle, scenario, currentSolution, requestBank, insCostMatrix, compatibilityRequestVehicle)

    end


end

function fillInsertionCostMatrix!(scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2})
    
    for r in requestBank
        for v in 1:length(scenario.vehicles)
            status, delta, pickUp, dropOff = findBestFeasibleInsertionRoute(scenario.requests[r], currentSolution.vehicleSchedules[v], scenario)
            if status
                insCostMatrix[r,v] = delta
            else
                insCostMatrix[r,v] = typemax(Float64)
                compatibilityRequestVehicle[r,v] = false
            end
        end
    end
    
end

function reCalcCostMatrix!(v::Int,scenario::Scenario, currentSolution::Solution, requestBank::Vector{Int}, insCostMatrix::Array{Float64,2}, compatibilityRequestVehicle::Array{Bool,2})
    for r in requestBank
        if compatibilityRequestVehicle[r,v]
            status, delta, pickUp, dropOff = findBestFeasibleInsertionRoute(scenario.requests[r], currentSolution.vehicleSchedules[v], scenario)
            if status
                insCostMatrix[r,v] = delta
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
function greedyInsertion(state::ALNSState,scenario::Scenario)
    @unpack destroyWeights, repairWeights, destroyNumberOfUses, repairNumberOfUses, bestSolution, currentSolution, requestBank = state
    newRequestBank = Int[]

    for r in requestBank
        request = scenario.requests[r]
        bestDelta = typemax(Float64)
        bestSchedule = VehicleSchedule()
        bestPickUp = -1
        bestDropOff = -1
        bestVehicle = -1

        for (idx,schedule) in enumerate(currentSolution.vehicleSchedules)
            status, delta, pickUp, dropOff = findBestFeasibleInsertionRoute(request, schedule, scenario)
            if status && delta < bestDelta
                bestDelta = delta
                bestSchedule = schedule
                bestPickUp = pickUp
                bestDropOff = dropOff
                bestVehicle = idx
            end
        end
        if (bestVehicle != -1)

            # Update solution pre
            state.currentSolution.totalCost -= currentSolution.vehicleSchedules[bestVehicle].totalCost
            state.currentSolution.totalDistance -= currentSolution.vehicleSchedules[bestVehicle].totalDistance
            state.currentSolution.totalRideTime -= currentSolution.vehicleSchedules[bestVehicle].totalTime
            state.currentSolution.totalIdleTime -= currentSolution.vehicleSchedules[bestVehicle].totalIdleTime

            # Insert request
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, scenario)
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


function findBestFeasibleInsertionRoute(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario)
    bestDelta = typemax(Float64)
    bestPickUp = -1
    bestDropOff = -1
    route = vehicleSchedule.route

    for i in 1:length(route)-1
        for j in i:length(route)-1
            feasible = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,i,j,scenario)
            if feasible
                delta = calculateInsertionCost(scenario.time,scenario.serviceTimes,vehicleSchedule,request,i,j)
                if delta < bestDelta
                    bestDelta = delta
                    bestPickUp = i
                    bestDropOff = j
                end
            end
        end
    end

    return bestDelta < typemax(Float64), bestDelta, bestPickUp, bestDropOff

end


function calculateInsertionCost(time::Array{Int,2},serviceTimes::Int,vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)

    route = vehicleSchedule.route

    # Get time when cend of service is for node before pick up
    if route[idxPickUp].activity.activityType == WAITING || route[idxPickUp].activity.activityType == DEPOT
        endOfServiceBeforePick = route[idxPickUp].activity.timeWindow.startTime
    else
        endOfServiceBeforePick = route[idxPickUp].endOfServiceTime
    end

    # Get time when end of service is for node before drop off
    if route[idxDropOff].activity.activityType == WAITING || route[idxDropOff].activity.activityType == DEPOT
        endOfServiceBeforeDrop = route[idxDropOff].activity.timeWindow.startTime
    else
        endOfServiceBeforeDrop = route[idxDropOff].endOfServiceTime
    end

    # Get time when arriving at node after pick up
    startOfServiceAfterPick = route[idxPickUp+1].startOfServiceTime

    # Get time when arriving at node after drop off
    startOfServiceAfterDrop = route[idxDropOff+1].startOfServiceTime


    #Get available service time windows
    earliestStartOfServicePickUp = max(endOfServiceBeforePick + time[route[idxPickUp].activity.id,request.pickUpActivity.id],request.pickUpActivity.timeWindow.startTime)
    latestStartOfServicePickUp = min(startOfServiceAfterPick - time[request.pickUpActivity.id,route[idxPickUp+1].activity.id] - serviceTimes,request.pickUpActivity.timeWindow.endTime)
    earliestStartOfServiceDropOff = max(endOfServiceBeforeDrop + time[route[idxDropOff].activity.id,request.dropOffActivity.id],request.dropOffActivity.timeWindow.startTime)
    latestStartOfServiceDropOff = min(startOfServiceAfterDrop - time[request.dropOffActivity.id,route[idxDropOff+1].activity.id] - serviceTimes,request.dropOffActivity.timeWindow.endTime)  

    # Get available service time window for pick up considering minimized excess drive time
    earliestStartOfServicePickUpMinimization = max(earliestStartOfServicePickUp,earliestStartOfServiceDropOff - max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes))
    latestStartOfServicePickUpMinimization = min(latestStartOfServicePickUp,latestStartOfServiceDropOff-max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes))

    # Choose the best time for pick up (Here the latest time is chosen)
    startOfServicePick = latestStartOfServicePickUpMinimization

    # Determine the time for drop off
    startOfServiceDrop = startOfServicePick + max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id]+serviceTimes)

    # Determine delta cost
    deltaCost = ((startOfServiceDrop - startOfServicePick) - time[request.pickUpActivity.id,request.dropOffActivity.id])/time[request.pickUpActivity.id,request.dropOffActivity.id]

    return deltaCost

end


end


