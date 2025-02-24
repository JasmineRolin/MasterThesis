module RouteUtils 

using UnPack, domain, ..CostCalculator

export printRoute,printSimpleRoute,insertRequest!,checkRouteFeasibility,checkFeasibilityOfInsertionAtPosition

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
Insert waiting before node with index idx
==#
function insertWaitingBeforeNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)
    route = vehicleSchedule.route
    # Insert before node
    if route[idx-1].endOfServiceTime + time[route[idx-1].activity.id,route[idx].activity.id] < route[idx].startOfServiceTime
        startOfServiceWaiting = route[idx-1].endOfServiceTime 
        endOfServiceWaiting = route[idx].startOfServiceTime - time[route[idx-1].activity.id,route[idx].activity.id]
        waitingActivity = ActivityAssignment(Activity(route[idx-1].activity.id,-1,WAITING,WALKING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
        insert!(route,idx,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx,vehicleSchedule.numberOfWalking[idx-1])
        insert!(vehicleSchedule.numberOfWheelchair,idx,vehicleSchedule.numberOfWheelchair[idx-1])
    end
end


#== 
Insert waiting after node with index idx
==#
function insertWaitingAfterNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)
    route = vehicleSchedule.route
    # Insert after node
    if route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id] < route[idx+1].startOfServiceTime
        startOfServiceWaiting = route[idx].endOfServiceTime 
        endOfServiceWaiting = route[idx+1].startOfServiceTime - time[route[idx].activity.id,route[idx+1].activity.id]
        waitingActivity = ActivityAssignment(Activity(route[idx].activity.id,-1,WAITING,WALKING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
        insert!(route,idx+1,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx,vehicleSchedule.numberOfWalking[idx-1])
        insert!(vehicleSchedule.numberOfWheelchair,idx,vehicleSchedule.numberOfWheelchair[idx-1])
    end
end


#==
Update waiting after node
==#
function updateWaitingAfterNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route
    if route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+2].activity.id] < route[idx+2].startOfServiceTime
        # Update waiting after node
        route[idx+1].startOfServiceTime = route[idx].endOfServiceTime
        route[idx+1].activity.timeWindow.startTime = route[idx].endOfServiceTime
    else
        # Remove waiting after node
        deleteat!(route,idx+1)
    end
end

#==
Update waiting before node
==#
function updateWaitingBeforeNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route
    if route[idx-2].endOfServiceTime + time[route[idx-2].activity.id,route[idx].activity.id] < route[idx].startOfServiceTime
        # Update waiting before node
        route[idx-1].endOfServiceTime = route[idx].startOfServiceTime
        route[idx-1].activity.timeWindow.endTime = route[idx].startOfServiceTime
    else
        # Remove waiting before node
        deleteat!(route,idx-1)
    end
end


#== 
Update or insert Waiting nodes 
==#
function updateWaiting!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int)
    route = vehicleSchedule.route

    if length(vehicleSchedule.route) == 2 && vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[2].activity.activityType == DEPOT
        insertWaitingAfterNode!(time,vehicleSchedule,1)
    elseif idxPickUp == 1 && idxPickUp == idxDropOff
        # After drop-off
        if route[idxPickUp+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        end
    elseif idxPickUp == idxDropOff
        # After drop-off
        if route[idxPickUp+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        end
        # Before pick up
        if route[idxPickUp].activity.activityType != WAITING
            insertWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
        end
    elseif idxPickUp == 1
        # After pick up
        if route[idxPickUp+2].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # Before drop-off
        if route[idxDropOff+1].activity.activityType != WAITING
            insertWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
        end
        # After drop-off
        if route[idxDropOff+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        end
    else
        # Before pick up
        if route[idxPickUp].activity.activityType != WAITING
            insertWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # After pick up
        if route[idxPickUp+2].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # Before drop-off
        if route[idxDropOff+1].activity.activityType != WAITING
            insertWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
        end
        # After drop-off
        if route[idxDropOff+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        end
    end

end

#==
Method to update route in vehicle schedule after insertion of request
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

    updateWaiting!(time,vehicleSchedule,idxPickUp,idxDropOff)
    

end

#==
# Method to update depots in vehicle schedule after insertion of request
==#
function updateDepots!(time::Array{Int,2}, vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)
     # Update active time windows
     route = vehicleSchedule.route
     if idxPickUp == 1
        
        newActiveTimeWindowStart = route[2].startOfServiceTime - time[route[1].activity.id,route[2].activity.id]

        vehicleSchedule.activeTimeWindow.startTime = newActiveTimeWindowStart
        route[1].activity.timeWindow.endTime =  newActiveTimeWindowStart
        route[1].startOfServiceTime = newActiveTimeWindowStart
        route[1].endOfServiceTime = newActiveTimeWindowStart
    end
    if (vehicleSchedule.route[end-1].activity.activityType == WAITING && idxDropOff == length(vehicleSchedule.route)-4)||(idxDropOff == length(vehicleSchedule.route) - 3)
        route = vehicleSchedule.route
        newActiveTimeWindowEnd = route[end-1].endOfServiceTime + time[route[end-1].activity.id,route[end].activity.id]

        vehicleSchedule.activeTimeWindow.endTime = newActiveTimeWindowEnd
        route[end].activity.timeWindow.startTime = newActiveTimeWindowEnd
        route[end].startOfServiceTime = newActiveTimeWindowEnd
        route[end].endOfServiceTime = newActiveTimeWindowEnd
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
    
    route = vehicleSchedule.route

    # Update total distance
    if idxDropOff == idxPickUp

        if route[idxPickUp+3].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+4].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+4].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+4].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+4].activity.id])
        end        

    else
        # PickUp
        if route[idxPickUp+2].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        end

        # DropOff
        if route[idxDropOff+2].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxDropOff].activity.id,vehicleSchedule.route[idxDropOff+3].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+3].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxDropOff].activity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
        end

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


#==
 Method to check feasibility of route  
==#
function checkRouteFeasibility(scenario::Scenario,vehicleSchedule::VehicleSchedule)
    @unpack vehicle, route, activeTimeWindow, totalDistance, totalCost,totalTime, numberOfWalking, numberOfWheelchair = vehicleSchedule
    @unpack requests, distance, time, serviceTimes, vehicleCostPrHour,vehicleStartUpCost  = scenario
    nRequests = length(requests)

    if length(route) == 2
        return true, "", Set{Int}()
    end

    # Check that active time window of vehicle is correct 
    if activeTimeWindow.startTime != route[1].startOfServiceTime || activeTimeWindow.endTime != route[end].endOfServiceTime
        msg = "ROUTE INFEASIBLE: Active time window of vehicle $(vehicle.id) is incorrect"
        return false, msg, Set{Int}()
    end

    # Check available time window of vehicle 
    if activeTimeWindow.startTime < vehicle.availableTimeWindow.startTime || activeTimeWindow.endTime > vehicle.availableTimeWindow.endTime
        msg = "ROUTE INFEASIBLE: Vehicle $(vehicle.id) is not available during the route"
        return false, msg, Set{Int}() 
    end
    
    # Check cost and total time 
    durationActiveTimeWindow = duration(activeTimeWindow)
    if totalTime != durationActiveTimeWindow
        msg = "ROUTE INFEASIBLE: Total time is incorrect for vehicle $(vehicle.id). Calculated time $(durationActiveTimeWindow), actual time $(totalTime)"
        return false, msg, Set{Int}()
    end
    if totalCost != vehicleCostPrHour * totalTime + vehicleStartUpCost
        msg = "ROUTE INFEASIBLE: Total cost is incorrect for vehicle $(vehicle.id). Calculated cost $(vehicleCostPrHour * totalTime + vehicleStartUpCost), actual cost $(totalCost)"
        return false, msg, Set{Int}()
    end
    
    
    # Check all activities on route 
    totalDistanceCheck = 0.0
    currentCapacities = Dict{MobilityType,Int}(WALKING => 0, WHEELCHAIR => 0)
    hasBeenServiced = Set{Int}() # TODO: Check if this still works with waiting activities
    endOfServiceTimePickUps = Dict{Int,Int}() # Keep track of end of service time for pick-ups
    for (idx,activityAssignment) in zip(2:length(route)-1, route[2:end-1]) # Do not check depots
        @unpack activity, startOfServiceTime, endOfServiceTime = activityAssignment

        # Check vehicle compatibility with the request
        if activity.mobilityType == WHEELCHAIR && vehicle.capacities[WHEELCHAIR] == 0
            msg = "ROUTE INFEASIBLE: Activity $(activity.id) is not compatible with vehicle $(vehicle.id)"
            return false, msg, Set{Int}()
        end

        # Checks only relevant for non-waiting nodes
        if activity.activityType != WAITING
            # Check that activity is not visited more than once
            if activity.id in hasBeenServiced
                msg = "ROUTE INFEASIBLE: Activity $(activity.id) visited more than once on vehicle $(vehicle.id)"
                return false, msg, Set{Int}()
            else
                push!(hasBeenServiced,activity.id)
            end

            # Check that start of service and end of service are feasible 
            if startOfServiceTime < route[idx-1].endOfServiceTime + time[route[idx-1].activity.id,activity.id]
                msg = "ROUTE INFEASIBLE: Start of service time $(startOfServiceTime) of activity $(activity.id) is not correct"
                return false, msg, Set{Int}()
            end
            if (endOfServiceTime != startOfServiceTime + serviceTimes[activity.mobilityType])
                msg = "ROUTE INFEASIBLE: End of service time $(endOfServiceTime) of activity $(activity.id) is not correct"
                return false, msg, Set{Int}()
            end

            # Update and check current capacities
            if activity.mobilityType == WHEELCHAIR
                currentCapacities[WHEELCHAIR] += findLoadOfActivity(activity)

                if currentCapacities[WHEELCHAIR] > vehicle.capacities[WHEELCHAIR] || currentCapacities[WHEELCHAIR] < 0
                    msg = "ROUTE INFEASIBLE: Capacities exceeded for vehicle $(vehicle.id)"
                    return false, msg, Set{Int}()
                end
            else
                # Walking customers can take wheelchair space if no walking space is available
                if currentCapacities[WALKING] == vehicle.capacities[WALKING] 
                    currentCapacities[WHEELCHAIR] += findLoadOfActivity(activity)
                else
                    currentCapacities[WALKING] += findLoadOfActivity(activity)
                end

                if currentCapacities[WHEELCHAIR] > vehicle.capacities[WHEELCHAIR] || currentCapacities[WHEELCHAIR] < 0 || currentCapacities[WALKING] > vehicle.capacities[WALKING] || currentCapacities[WALKING] < 0
                    msg = "ROUTE INFEASIBLE: Capacities exceeded for vehicle $(vehicle.id)"
                    return false, msg, Set{Int}() 
                end

            end

            if currentCapacities[WHEELCHAIR] != numberOfWheelchair[idx] || currentCapacities[WALKING] != numberOfWalking[idx]
                msg = "ROUTE INFEASIBLE: Capacities not updated correctly for vehicle $(vehicle.id)"
                return false, msg, Set{Int}() 
            end


        end
        
        # Check that pickup is serviced before drop-off and that maximum ride time is satisfied 
        if activity.activityType == PICKUP
            endOfServiceTimePickUps[activity.id] = endOfServiceTime
        elseif activity.activityType == DROPOFF 
            pickUpId = findCorrespondingId(activity,nRequests)
            if !(pickUpId in hasBeenServiced)
                msg = "ROUTE INFEASIBLE: Drop-off $(activity.id) before pick-up, vehicle: $(vehicle.id)"
                return false, msg, Set{Int}()
            end

            rideTime = endOfServiceTime - endOfServiceTimePickUps[pickUpId]
            if rideTime > requests[activity.requestId].maximumRideTime || rideTime < requests[activity.requestId].directDriveTime
                msg = "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off $(activity.id) on vehicle $(vehicle.id)"
                return false, msg, Set{Int}()
            end

        end


        # Check that time windows are respected
        if startOfServiceTime < activity.timeWindow.startTime || startOfServiceTime > activity.timeWindow.endTime
            msg = "ROUTE INFEASIBLE: Time window not respected for activity $(activity.id) on vehicle $(vehicle.id), Start/End of Service: ($startOfServiceTime, $endOfServiceTime), Time Window: ($(activity.timeWindow.startTime), $(activity.timeWindow.endTime))"
            return false, msg, Set{Int}()
        end

        
        # Keep track of total distance and total time 
        totalDistanceCheck += distance[route[idx-1].activity.id,activity.id]
    end

    # Add end depot to total distance 
    totalDistanceCheck += distance[route[end-1].activity.id,route[end].activity.id]

    # Check that total distance is correct
    if totalDistanceCheck != totalDistance
        msg = "ROUTE INFEASIBLE: Total distance $(totalDistance) is incorrect"
        return false, msg, Set{Int}() 
    end
    
   
    return true, "", hasBeenServiced
    
end


end