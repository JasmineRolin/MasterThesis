module SolutionValidator

using UnPack, domain, ..RouteUtils, ..CostCalculator

export checkSolutionFeasibility,checkRouteFeasibility, checkSolutionFeasibilityOnline,checkRouteFeasibilityOnline


#==
# Function to check feasibility of online solution 
==#
function checkSolutionFeasibilityOnline(scenario::Scenario,state::State;nExpected::Int=0)
    @unpack solution, event, visitedRoute, totalNTaxi = state
    checkSolutionFeasibilityOnline(scenario,solution,event,visitedRoute,totalNTaxi; nExpected=nExpected)
end

function checkSolutionFeasibilityOnline(scenario::Scenario,solution::Solution,event::Request,visitedRoute::Dict{Int, Dict{String, Int}}, totalNTaxi::Int;nExpected::Int=0)
    @unpack vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, totalIdleTime = solution

    # Keep track of serviced activities assuming that activity 
    servicedActivities = Set{Int}()
    servicedPickUpActivities = Set{Int}()
    union!(servicedPickUpActivities, keys(visitedRoute))

    # Keep track of cost, total distance and total time of solution
    totalCostCheck = 0.0 
    totalRideTimeCheck = 0
    totalDistanceCheck = 0.0
    totalIdleTimeCheck = 0.0

    # Check all routes 
    for vehicleSchedule in vehicleSchedules
        feasible, msg, servicedActivitiesInRoute, pickUpActivitiesInRoute = checkRouteFeasibilityOnline(scenario,vehicleSchedule,visitedRoute)

        # Return if route is not feasible 
        if !feasible
            return false, msg
        end

        # Update serviced activities
        for activity in servicedActivitiesInRoute
            if activity in servicedActivities
                msg = "SOLUTION INFEASIBLE: Activity $(activity) is serviced more than once"
                throw(msg)
                return false, msg
            end

            push!(servicedActivities,activity)
        end

        # Update serviced pick up
        for activity in pickUpActivitiesInRoute
            if activity in servicedPickUpActivities
                msg = "SOLUTION INFEASIBLE: Pick up $(activity) is serviced more than once"
                throw(msg)
                return false, msg
            end

            push!(servicedPickUpActivities,activity)
        end

        # Count KPIs
        totalRideTimeCheck += vehicleSchedule.totalTime
        totalDistanceCheck += vehicleSchedule.totalDistance
        totalCostCheck += vehicleSchedule.totalCost
        totalIdleTimeCheck += vehicleSchedule.totalIdleTime
    end

    # Check that all activities are serviced
    considered = Set{Int}()
    union!(considered, (r.id for r in scenario.offlineRequests))  
    if event.id != 0  
        for onlineRequest in scenario.onlineRequests
            push!(considered, onlineRequest.id)
            if event.id == onlineRequest.id
                break
            end
        end
    end
    notServicedRequests = setdiff(considered, servicedPickUpActivities)

    if totalNTaxi + nTaxi + nExpected != length(notServicedRequests) 
        msg = "SOLUTION INFEASIBLE: Not all requests are serviced. Serviced: $(length(servicedPickUpActivities)), not serviced: $(length(notServicedRequests)), nTaxi: $(nTaxi)"
        return false, msg
    end

    # Check cost, distance and time of solution 
    totalCostCheck += (nTaxi + totalNTaxi) * scenario.taxiParameter #?
    if !isapprox(totalCostCheck,totalCost,atol=0.0001) 
        msg = "SOLUTION INFEASIBLE: Total cost of solution is incorrect. Calculated: $(totalCostCheck), actual: $(totalCost), diff: $(abs(totalCostCheck-totalCost))"
        return false, msg
    end
    if !isapprox(totalDistanceCheck,totalDistance,atol=0.0001)
        msg = "SOLUTION INFEASIBLE: Total distance of solution is incorrect. Calculated: $(totalDistanceCheck), actual: $(totalDistance)"
        return false, msg
    end
    if totalRideTimeCheck != totalRideTime
        msg = "SOLUTION INFEASIBLE: Total ride time of solution is incorrect. Calculated: $(totalRideTimeCheck), actual: $(totalRideTime)"
        return false, msg
    end
    if totalIdleTimeCheck != totalIdleTime
        msg = "SOLUTION INFEASIBLE: Total idle time of solution is incorrect. Calculated: $(totalIdleTimeCheck), actual: $(totalIdleTime)"
        return false, msg
    end


    return true, ""
    
end


#==
 Method to check online feasibility of route  
==#
function checkRouteFeasibilityOnline(scenario::Scenario,vehicleSchedule::VehicleSchedule,visitedRoute::Dict{Int, Dict{String, Int}})
    @unpack vehicle, route, activeTimeWindow, totalDistance, totalCost,totalTime, totalIdleTime, numberOfWalking = vehicleSchedule
    @unpack requests, distance, time, serviceTimes, vehicleCostPrHour,vehicleStartUpCost  = scenario
    nRequests = length(requests)

    if length(route) == 2 && route[1].activity.activityType == DEPOT && route[2].activity.activityType == DEPOT
        return true, "", Set{Int}(), Set{Int}()
    elseif length(route) == 0
        return true, "", Set{Int}(), Set{Int}()
    end

    # Check that active time window of vehicle is correct 
    if activeTimeWindow.startTime != route[1].startOfServiceTime || activeTimeWindow.endTime != route[end].endOfServiceTime
        msg = "ROUTE INFEASIBLE: Active time window of vehicle $(vehicle.id) is incorrect"
        return false, msg, Set{Int}(), Set{Int}()
    end

    # Check available time window of vehicle 
    if activeTimeWindow.startTime < vehicle.availableTimeWindow.startTime || activeTimeWindow.endTime > vehicle.availableTimeWindow.endTime
        msg = "ROUTE INFEASIBLE: Vehicle $(vehicle.id) is not available during the route"
        return false, msg, Set{Int}(), Set{Int}() 
    end

    # Special check if route is only 1 activity
    if length(route) == 1 && route[1].activity.activityType == DEPOT
        return true, "", Set{Int}(), Set{Int}()

        if !isapprox(totalTime,0) && !isapprox(totalDistance,0) && !isapprox(totalCost,0) && !isapprox(totalIdleTIme,0)
            msg = "ROUTE INFEASIBLE: Route has only depot, but time, distance and cost is not zero"
            return false, msg, Set{Int}(), Set{Int}()
        end 

    elseif length(route) == 1
        msg = "ROUTE INFEASIBLE: Route has only one activity, but it is not a depot"
        return false, msg, Set{Int}(), Set{Int}()
    end
    
    # Check cost and total time 
    durationActiveTimeWindow = duration(activeTimeWindow)
    if totalTime != durationActiveTimeWindow
        msg = "ROUTE INFEASIBLE: Total time is incorrect for vehicle $(vehicle.id). Calculated time $(durationActiveTimeWindow), actual time $(totalTime)"
        return false, msg, Set{Int}(), Set{Int}()
    end
    if !isapprox(totalCost, getTotalCostRouteOnline(scenario.time,route,visitedRoute,scenario.serviceTimes),atol=0.0001) 
        msg = "ROUTE INFEASIBLE: Total cost is incorrect for vehicle $(vehicle.id). Calculated cost $(getTotalCostRouteOnline(scenario.time,route,visitedRoute,scenario.serviceTimes)), actual cost $(totalCost), diff $(abs(totalCost-getTotalCostRouteOnline(scenario.time,route,visitedRoute,scenario.serviceTimes))))"
        return false, msg, Set{Int}(), Set{Int}()
    end

    
    # Check all activities on route 
    totalDistanceCheck = 0.0
    totalIdleTimeCheck = 0.0
    currentCapacities = 0

    # Determine initial current capacity 
    visitedRouteIds = keys(visitedRoute)
    for activityAssignment in route 
        if activityAssignment.activity.activityType == DROPOFF && activityAssignment.activity.requestId in visitedRouteIds
            currentCapacities += 1
        end
    end

    hasBeenServiced = Vector{Int}() 
    hasBeenServicedRequest = Vector{Int}() 
    endOfServiceTimePickUps = Dict{Int,Int}() # Keep track of end of service time for pick-ups
    for (idx,activityAssignment) in zip(1:length(route)-1, route[1:end-1]) # Do not check last depot 
        @unpack activity, startOfServiceTime, endOfServiceTime = activityAssignment
        
        # Check that pickup is serviced before drop-off and that maximum ride time is satisfied 
        if activity.activityType == PICKUP
            push!(hasBeenServicedRequest,activity.id)
            endOfServiceTimePickUps[activity.id] = endOfServiceTime
        elseif activity.activityType == DROPOFF 
            pickUpId = findCorrespondingId(activity,nRequests)
            if !(pickUpId in hasBeenServicedRequest || pickUpId in keys(visitedRoute)) 
                msg = "ROUTE INFEASIBLE: Drop-off $(activity.id) before pick-up, vehicle: $(vehicle.id)"
                return false, msg, Set{Int}(), Set{Int}()
            end

            endOfservicePickUp = haskey(visitedRoute, pickUpId) ? visitedRoute[pickUpId]["PickUpServiceStart"] + scenario.serviceTimes : endOfServiceTimePickUps[pickUpId]
            rideTime = startOfServiceTime - endOfservicePickUp
            if rideTime > requests[activity.requestId].maximumRideTime || rideTime < requests[activity.requestId].directDriveTime
                msg = "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off $(activity.id) on vehicle $(vehicle.id), END PU/START DO: ($(endOfservicePickUp), $(startOfServiceTime)), Ride time: $(rideTime), Maximum ride time: $(requests[activity.requestId].maximumRideTime), direct drive time: $(requests[activity.requestId].directDriveTime)"
                return false, msg, Set{Int}(), Set{Int}()
            end
        end

        # Check that time windows are respected
        if startOfServiceTime < activity.timeWindow.startTime || startOfServiceTime > activity.timeWindow.endTime
            msg = "ROUTE INFEASIBLE: Time window not respected for activity $(activity.id) on vehicle $(vehicle.id), Start/End of Service: ($startOfServiceTime, $endOfServiceTime), Time Window: ($(activity.timeWindow.startTime), $(activity.timeWindow.endTime))"
            return false, msg, Set{Int}(), Set{Int}()
        end

        # Checks only relevant for non-waiting and non-depots nodes
        if activity.activityType != WAITING && activity.activityType != DEPOT
            # Check that activity is not visited more than once
            if activity.id in hasBeenServiced
                msg = "ROUTE INFEASIBLE: Activity $(activity.id) visited more than once on vehicle $(vehicle.id)"
                return false, msg, Set{Int}(), Set{Int}()
            else
                push!(hasBeenServiced,activity.id)
            end

            # Check that start of service and end of service are feasible 
            if idx > 1 && startOfServiceTime < route[idx-1].endOfServiceTime + time[route[idx-1].activity.id,activity.id]
                msg = "ROUTE INFEASIBLE: Start of service time $(startOfServiceTime) of activity $(activity.id) is not correct on vehicle $(vehicle.id)"
                return false, msg, Set{Int}(), Set{Int}()
            end
            if (endOfServiceTime != startOfServiceTime + serviceTimes)
                msg = "ROUTE INFEASIBLE: End of service time $(endOfServiceTime) of activity $(activity.id) is not correct"
                return false, msg, Set{Int}(), Set{Int}()
            end

            
            # Update and check current capacities
            currentCapacities += findLoadOfActivity(activity)

            if currentCapacities > vehicle.totalCapacity 
                msg = "ROUTE INFEASIBLE: Capacities exceeded for vehicle $(vehicle.id)"
                    return false, msg, Set{Int}(), Set{Int}()
            end

            if currentCapacities != numberOfWalking[idx] 
                msg = "ROUTE INFEASIBLE: Capacities not updated correctly for vehicle $(vehicle.id), current capacities $(currentCapacities), number of walking $(numberOfWalking[idx])"
                return false, msg, Set{Int}(), Set{Int}() 
            end
        elseif activity.activityType == WAITING
            totalIdleTimeCheck += endOfServiceTime - startOfServiceTime
        end
        
        # Keep track of total distance and total time 
        if idx > 1
            totalDistanceCheck += distance[route[idx-1].activity.id,activity.id]
        end
    end

    # Add end depot to total distance 
    totalDistanceCheck += distance[route[end-1].activity.id,route[end].activity.id]

    # Check that total distance is correct
    if !isapprox(totalDistanceCheck, totalDistance,atol=0.0001)
        msg = "ROUTE INFEASIBLE: Total distance $(totalDistance) is incorrect. Calculated: $(totalDistanceCheck), vehicle: $(vehicle.id)"
        return false, msg, Set{Int}(), Set{Int}() 
    end

    # Check that waiting nodes are inserted correctly with respect to time
    activeTime = vehicleSchedule.activeTimeWindow.endTime - vehicleSchedule.activeTimeWindow.startTime
    totalTime = 0
    for idx in 1:length(route)-1
        if route[idx].activity.activityType == WAITING
            totalTime += route[idx].endOfServiceTime - route[idx].startOfServiceTime
        elseif (route[idx].activity.activityType == PICKUP) || (route[idx].activity.activityType == DROPOFF)
            totalTime += serviceTimes
        end

        totalTime += time[route[idx].activity.id,route[idx+1].activity.id]
    end

    if totalTime != activeTime
        msg = "ROUTE INFEASIBLE: Total time based on waiting nodes $(totalTime) is incorrect compared to active time $(activeTime) for vehicle $(vehicle.id)"
        return false, msg, Set{Int}(), Set{Int}()
    end

    if totalIdleTimeCheck != vehicleSchedule.totalIdleTime
        msg = "ROUTE INFEASIBLE: Total idle time $(vehicleSchedule.totalIdleTime) is incorrect. Calculated: $(totalIdleTimeCheck), vehicle: $(vehicle.id)"
        return false, msg, Set{Int}(), Set{Int}()
    end
    
   
    return true, "", hasBeenServiced, hasBeenServicedRequest
    
end


end 