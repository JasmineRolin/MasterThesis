module RepairMethods 

using utils, UnPack, domain
using ..ALNSDomain

export greedyInsertion

#==
 Module that containts repair methods 
==#
# TODO: implement methods 
# TODO: methods should all have same input (solution,parameters)



function greedyInsertion(state::ALNSState)
    @unpack destroyWeights, repairWeights, destroyNumberOfUses, repairNumberOfUses, bestSolution, currentSolution, requestBank = state

    for request in requestBank
        bestDelta = typemax(Float64)
        bestVehicle = -1
        bestPickUp = -1
        bestDropOff = -1
        typeOfSeat = nothing

        for schedule in currentSolution.vehicleSchedules
            status, delta, pickUp, dropOff, typeOfSeat = findBestInsertionRouteGreedy(request, schedule, scenario)
            if status && delta < bestDelta
                bestDelta = delta
                bestVehicle = schedule.vehicle
                bestPickUp = pickUp
                bestDropOff = dropOff
            end
        end
        if bestVehicle != -1
            insertRequest!(request, currentSolution.vehicleSchedules[bestVehicle], bestPickUp, bestDropOff, typeOfSeat, scenario)
        else
            currentSolution.nTaxi += 1
        end
    end

    return solution
end


function findBestInsertionRouteGreedy(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario)
    bestDelta = typemax(Float64)
    bestPickUp = -1
    bestDropOff = -1
    bestTypeOfSeat = nothing

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

    return bestDelta < typemax(Float64), bestDelta, bestPickUp, bestDropOff, typeOfSeat

end


function calculateInsertionCost(request::Request, vehicleSchedule::VehicleSchedule, i::Int, j::Int, scenario::Scenario)
    # Calculate cost of inserting request at position i,j in route
    newVehicleSchedule = copy(vehicleSchedule)
    updateRoute!(scenario.time,scenario.serviceTimes,newVehicleSchedule,request,i,j)
    newTotalCost = getTotalCostRoute(scenario,newVehicleSchedule.route)
    return newTotalCost - vehicleSchedule.totalCost
end


end


