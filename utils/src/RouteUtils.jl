module RouteUtils 

using UnPack, domain, Printf, ..CostCalculator

export printRoute,printSimpleRoute,insertRequest!,checkFeasibilityOfInsertionAtPosition,printRouteHorizontal,printSolution


#==
# Method to print solution 
==#
function printSolution(solution::Solution,printRouteFunc::Function)
    for schedule in solution.vehicleSchedules
        printRouteFunc(schedule)
    end
end

#==
 Method to print vehicle schedule 
==#
function printRoute(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Active Time Window: ", "(",schedule.activeTimeWindow.startTime, ",", schedule.activeTimeWindow.endTime,")")
    println("Total Distance: ", schedule.totalDistance, " km")
    println("Total time: ", schedule.totalTime, " min")
    println("Total Cost: \$", schedule.totalCost)
    println("Wheelchair capacities: ", schedule.numberOfWheelchair)
    println("Walking capacities: ", schedule.numberOfWalking)
    println("\nRoute:")
    
    for (i, assignment) in enumerate(schedule.route)
        println("  Step ", i, ":")
        println("    Mobility Type: ", assignment.activity.mobilityType)
        println("    Activity Type: ", assignment.activity.activityType)
        println("    Location: ", assignment.activity.location.name, " (",assignment.activity.location.lat, ",",assignment.activity.location.long,")")
        println("    Start/end of service: ","(", assignment.startOfServiceTime, ",", assignment.endOfServiceTime,")")
        println("    Time Window: ", "(",assignment.activity.timeWindow.startTime, ",", assignment.activity.timeWindow.endTime,")")
        println("    Load: (", schedule.numberOfWalking[i], ",", schedule.numberOfWheelchair[i],")")
    end
    println("\n--------------------------------------")
end

function printRouteHorizontal(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Available Time Window: ($(schedule.vehicle.availableTimeWindow.startTime), $(schedule.vehicle.availableTimeWindow.endTime)), Active Time Window: ($(schedule.activeTimeWindow.startTime), $(schedule.activeTimeWindow.endTime))")
    println("Total Distance: $(schedule.totalDistance) km, Total Time: $(schedule.totalTime) min, Total Cost: \$$(schedule.totalCost)")
    println("Wheelchair Capacities: $(schedule.numberOfWheelchair), Walking Capacities: $(schedule.numberOfWalking)")
    
    println("------------------------------------------------------------------------------------------------------------")
    println("| Step | Mobility Type | Activity Type |  Location  | Start/End Service | Time Window | (Walking, Wheelchair) |")
    println("------------------------------------------------------------------------------------------------------------")

    for (i, assignment) in enumerate(schedule.route)
        start_service = assignment.startOfServiceTime
        end_service = assignment.endOfServiceTime
        activity = assignment.activity
        location = activity.location
        time_window = activity.timeWindow
        
        # Extract load details safely
        walking_load = i <= length(schedule.numberOfWalking) ? schedule.numberOfWalking[i] : "N/A"
        wheelchair_load = i <= length(schedule.numberOfWheelchair) ? schedule.numberOfWheelchair[i] : "N/A"
        
        # Print each route step in a single horizontal line
        @printf("| %-4d | %-13s | %-13s | %-10s | (%5d, %5d) | (%5d, %5d) | (%3s, %3s) |\n",
                i,
                activity.mobilityType,
                activity.activityType,
                location.name, 
                start_service, end_service,
                time_window.startTime, time_window.endTime,
                walking_load, wheelchair_load)
    end
    println("------------------------------------------------------------------------------------------------------------\n")
end


function printSimpleRoute(schedule::VehicleSchedule)
    print("Route ",schedule.vehicle.id,": ")
    
    route_ids = [assignment.activity.location.name for assignment in schedule.route]
    
    println(join(route_ids, " -> "))
end


# ----------
# Function to insert a request in a vehicle schedule
# ----------
# idxPickUp: index of link where pickup should be inserted 
# idxDropOff: index of link where dropoff should be inserted 
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,typeOfSeat::MobilityType,scenario::Scenario)

    # Update route
    updateRoute!(scenario.time,scenario.serviceTimes,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update depots
    updateDepots!(scenario.time,vehicleSchedule,request,idxPickUp,idxDropOff)
   
    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff,typeOfSeat)

    # Update total distance
    updateDistance!(scenario.distance,vehicleSchedule,request,idxDropOff,idxPickUp)

    # Update total time 
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)

    # Update total cost
    vehicleSchedule.totalCost = getTotalCostRoute(scenario, vehicleSchedule.totalTime)
end


#==
Method to ipdate route in vehicle schedule after insertion of request
==#
function updateRoute!(time::Array{Int,2},serviceTimes::Dict{MobilityType,Int},vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)

    # Special case when only two depots due to how initial time windows are. Insert as early as possible
    if length(vehicleSchedule.route) == 2 && vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[2].activity.activityType == DEPOT
        startOfServicePick = max(vehicleSchedule.route[1].activity.timeWindow.startTime + time[vehicleSchedule.route[1].activity.id,request.pickUpActivity.id],request.pickUpActivity.timeWindow.startTime)
        endOfServicePick = startOfServicePick + serviceTimes[request.pickUpActivity.mobilityType]

        startOfServiceDrop = max(endOfServicePick + time[request.pickUpActivity.id,request.dropOffActivity.id],request.dropOffActivity.timeWindow.startTime)
        endOfServiceDrop = startOfServiceDrop + serviceTimes[request.dropOffActivity.mobilityType]

    # Insert as late as possible in the route to minimize active time for vehicle
    elseif idxPickUp == 1 && idxPickUp == idxDropOff
        endOfServiceDrop = min(request.dropOffActivity.timeWindow.endTime + serviceTimes[request.dropOffActivity.mobilityType],vehicleSchedule.route[idxPickUp+1].startOfServiceTime-time[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+1].activity.id])
        startOfServiceDrop = endOfServiceDrop - serviceTimes[request.dropOffActivity.mobilityType]

        endOfServicePick = min(startOfServiceDrop-time[request.pickUpActivity.id,request.dropOffActivity.id],request.pickUpActivity.timeWindow.endTime+serviceTimes[request.pickUpActivity.mobilityType])
        startOfServicePick = endOfServicePick - serviceTimes[request.pickUpActivity.mobilityType]

    # Same pick-up and drop-off index. Insert as early as possible
    elseif idxPickUp == idxDropOff
        earliestStartOfServicePick = vehicleSchedule.route[idxPickUp].endOfServiceTime + time[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] 
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)

        earliestStartOfServiceDrop = startOfServicePick + serviceTimes[request.pickUpActivity.mobilityType] + time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes[request.dropOffActivity.mobilityType]
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)

    # Pick-up is first activity in route. Insert pick up as late as possible and drop-off as early as possible
    elseif idxPickUp == 1
        latestStartOfServicePick = vehicleSchedule.route[idxPickUp+1].activity.timeWindow.startTime - time[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+1].activity.id] 
        startOfServicePick = max(latestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)

        earliestStartOfServiceDrop = vehicleSchedule.route[idxDropOff].endOfServiceTime + time[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] 
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
    
    # Insert as early as possible 
    else
        earliestStartOfServicePick = vehicleSchedule.route[idxPickUp].endOfServiceTime + time[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] 
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)

        earliestStartOfServiceDrop = vehicleSchedule.route[idxDropOff].endOfServiceTime + time[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] 
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
    end

    # Insert request
    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick + serviceTimes[request.pickUpActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop + serviceTimes[request.dropOffActivity.mobilityType])
    insert!(vehicleSchedule.route,idxPickUp+1,pickUpActivity)
    insert!(vehicleSchedule.route,idxDropOff+2,dropOffActivity)
end

#==
# Method to update depots in vehicle schedule after insertion of request
==#
function updateDepots!(time::Array{Int,2}, vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)
     # Update active time windows
     if idxPickUp == 1
        newActiveTimeWindowStart = vehicleSchedule.route[idxPickUp+1].startOfServiceTime - time[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id]

        vehicleSchedule.activeTimeWindow.startTime = newActiveTimeWindowStart
        vehicleSchedule.route[1].activity.timeWindow.endTime =  newActiveTimeWindowStart
        vehicleSchedule.route[1].startOfServiceTime = newActiveTimeWindowStart
        vehicleSchedule.route[1].endOfServiceTime = newActiveTimeWindowStart
    end
    if idxDropOff == length(vehicleSchedule.route) - 3
        newActiveTimeWindowEnd = vehicleSchedule.route[idxDropOff+2].endOfServiceTime + time[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+3].activity.id]

        vehicleSchedule.activeTimeWindow.endTime = newActiveTimeWindowEnd
        vehicleSchedule.route[end].activity.timeWindow.startTime = newActiveTimeWindowEnd
        vehicleSchedule.route[end].startOfServiceTime = newActiveTimeWindowEnd
        vehicleSchedule.route[end].endOfServiceTime = newActiveTimeWindowEnd
    end
end

#==
# Method to update capacities of vehicle schedule after insertion of request
==#
function updateCapacities!(vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,typeOfSeat::MobilityType)
     # Update capacities
     if typeOfSeat == WHEELCHAIR
        # Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,vehicleSchedule.numberOfWheelchair[idxPickUp]+1)
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,vehicleSchedule.numberOfWheelchair[idxDropOff])
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWheelchair[i] = vehicleSchedule.numberOfWheelchair[i] + 1
        end

        #Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp])
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff+2])

    else
        # Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp]+1)
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff])
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWalking[i] = vehicleSchedule.numberOfWalking[i] + 1
        end

        #Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,vehicleSchedule.numberOfWheelchair[idxPickUp])
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,vehicleSchedule.numberOfWheelchair[idxDropOff+2])
    end
end

#==
# Method to update total distance of vehicle schedule after insertion of request
==#
function updateDistance!(distance::Array{Float64,2},vehicleSchedule::VehicleSchedule,request::Request,idxDropOff::Int,idxPickUp)
     # Update total distance
     if idxDropOff == idxPickUp
        vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
        vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
    else
        # PickUp
        vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        # DropOff
        vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxDropOff].activity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
        vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
    end
end


# ----------
# Function to check feasibility of given placement of a request for in a vehicle schedule 
# ----------
# OBS: Made for when a service time is determined, and it cannot be changed
function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)
    typeOfSeat = nothing

    # Check vehicle capacity
    if request.mobilityType == WHEELCHAIR && all(vehicleSchedule.numberOfWheelchair[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.capacities[WHEELCHAIR])
        typeOfSeat = WHEELCHAIR
    elseif request.mobilityType == WALKING && all(vehicleSchedule.numberOfWalking[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.capacities[WALKING])
        typeOfSeat = WALKING
    elseif request.mobilityType == WALKING && all(vehicleSchedule.numberOfWheelchair[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.capacities[WHEELCHAIR])
        typeOfSeat = WHEELCHAIR
    else
        println("Infeasible: Not enough capacity")
        return false, typeOfSeat
    end

    # Check if insertion is feasible 
    if pickUpIdx == dropOffIdx
        # Determine arrival times
        idx = pickUpIdx

        # Determine arrival times for different cases
        if idx == 1
            earliestStartOfServicePick = vehicleSchedule.route[idx].activity.timeWindow.startTime + scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
            startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
            endOfPickUp = startOfServicePick + scenario.serviceTimes[request.pickUpActivity.mobilityType]

            earliestStartOfServiceDrop = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id]
            startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
            endOfDropOff = startOfServiceDrop + scenario.serviceTimes[request.dropOffActivity.mobilityType]
            arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]
        else
            earliestStartOfServicePick = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
            startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
            endOfPickUp = startOfServicePick + scenario.serviceTimes[request.pickUpActivity.mobilityType]

            earliestStartOfServiceDrop = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id]
            startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
            endOfDropOff = startOfServiceDrop + scenario.serviceTimes[request.dropOffActivity.mobilityType]
            arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]
        end

        # Check drive time: First node
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime
            println("Infeasible: Drive time from first node")
            return false, typeOfSeat
        end
        
        # Check drive time:Next node
        if idx == length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
            println("Infeasible: Drive time to next node")
            return false, typeOfSeat
        elseif idx < length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            println("Infeasible: Drive time to next node")
            return false, typeOfSeat
        end


    else
        for activity in [request.pickUpActivity, request.dropOffActivity]
            if activity == request.pickUpActivity
                idx = pickUpIdx
            else
                idx = dropOffIdx
            end
            
            
            # Check drive time: Vehicle cannot reach activity within timewindow from first node
            if idx == 1 && (vehicleSchedule.vehicle.availableTimeWindow.startTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] > activity.timeWindow.endTime)
                println("Infeasible: Drive time from first node")
                return false, typeOfSeat
            elseif idx > 1 && (vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] > activity.timeWindow.endTime)
                println("Infeasible: Drive time from first node")
                return false, typeOfSeat
            end
            
            # Check drive time: Vehicle cannot reach next node from activity
            endService = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
            arrivalNextNode = endService + scenario.time[activity.id, vehicleSchedule.route[idx+1].activity.id]
            if (idx == length(vehicleSchedule.route)-1) && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
                println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            elseif (idx < length(vehicleSchedule.route)-1) && arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
                println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            end
    
        end
    end

    
        
    # If all checks pass, the activity is feasible
    println("FEASIBLE")
    return true, typeOfSeat
end



end