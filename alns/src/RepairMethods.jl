module RepairMethods 

using utils, UnPack, domain
using ..ALNSDomain

export greedyInsertion

#==
 Module that containts repair methods 
==#
# TODO: implement methods 
# TODO: methods should all have same input (solution,parameters)



function greedyInsertion(state::ALNSState,scenario::Scenario)
    @unpack destroyWeights, repairWeights, destroyNumberOfUses, repairNumberOfUses, bestSolution, currentSolution, requestBank = state

    for request in requestBank
        bestDelta = typemax(Float64)
        bestSchedule = VehicleSchedule()
        bestPickUp = -1
        bestDropOff = -1
        bestTypeOfSeat = nothing

        for schedule in currentSolution.vehicleSchedules
            status, delta, pickUp, dropOff, bestTypeOfSeat = findBestInsertionRouteGreedy(request, schedule, scenario)
            if status && delta < bestDelta
                bestDelta = delta
                bestSchedule = schedule
                bestPickUp = pickUp
                bestDropOff = dropOff
            end
        end
        if bestTypeOfSeat != -1
            insertRequest!(request, bestSchedule, bestPickUp, bestDropOff, bestTypeOfSeat, scenario)
        else
            currentSolution.nTaxi += 1
        end
    end

    return currentSolution
end


function findBestInsertionRouteGreedy(request::Request, vehicleSchedule::VehicleSchedule, scenario::Scenario)
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
                println("--------")
                println(i)
                println(j)
                println(delta)
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


