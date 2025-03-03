module SolutionValidator

using UnPack, domain, ..RouteUtils, ..CostCalculator

export checkSolutionFeasibility,checkRouteFeasibility

#==
# Function to check feasibility of solution 
==#
function checkSolutionFeasibility(scenario::Scenario,solution::Solution)
    @unpack vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, totalIdleTime = solution

    # Collect ids of all activities in scenario - assuming activities have id 1:2*nRequests
    nRequests = length(scenario.requests)
    activityIds = collect(1:(2*nRequests))
    nActivities = length(activityIds)

    # Keep track of serviced activities assuming that activity 
    servicedActivities = Set{Int}()

    # Keep track of cost, total distance and total time of solution
    totalCostCheck = 0.0 
    totalRideTimeCheck = 0
    totalDistanceCheck = 0.0
    # TODO: keep track of idle time 

    # Check all routes 
    for vehicleSchedule in vehicleSchedules
        feasible, msg, servicedActivitiesInRoute = checkRouteFeasibility(scenario,vehicleSchedule)

        # Return if route is not feasible 
        if !feasible
            return false, msg
        end

        # Update serviced activities
        for activity in servicedActivitiesInRoute
            if activity in servicedActivities
                msg = "SOLUTION INFEASIBLE: Activity $(activity) is serviced more than once"
                return false, msg
            end

            push!(servicedActivities,activity)
        end

        # Count KPIs
        totalRideTimeCheck += vehicleSchedule.totalTime
        totalDistanceCheck += vehicleSchedule.totalDistance
        totalCostCheck += vehicleSchedule.totalCost
    end

    # Check that all activities are serviced
    if (nActivities-length(servicedActivities)) != 2*nTaxi # TODO: add check if we add list of activities serviced by taxi 
        msg = "SOLUTION INFEASIBLE: Not all activities are serviced"
        return false, msg
    end

    # Check cost, distance and time of solution 
    if totalCostCheck != totalCost
        msg = "SOLUTION INFEASIBLE: Total cost of solution is incorrect. Calculated: $(totalCostCheck), actual: $(totalCost)"
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


    return true, ""
    
end


#==
 Method to check feasibility of route  
==#
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
    if totalCost != getTotalCostRoute(scenario,route)
        msg = "ROUTE INFEASIBLE: Total cost is incorrect for vehicle $(vehicle.id). Calculated cost $(getTotalCostRoute(scenario,route)), actual cost $(totalCost)"
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
                msg = "ROUTE INFEASIBLE: Start of service time $(startOfServiceTime) of activity $(activity.id) is not correct on vehicle $(vehicle.id)"
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

        
        # Keep track of total distance and total time 
        totalDistanceCheck += distance[route[idx-1].activity.id,activity.id]
    end

    # Add end depot to total distance 
    totalDistanceCheck += distance[route[end-1].activity.id,route[end].activity.id]

    # Check that total distance is correct
    if !isapprox(totalDistanceCheck, totalDistance,atol=0.0001)
        msg = "ROUTE INFEASIBLE: Total distance $(totalDistance) is incorrect. Calculated: $(totalDistanceCheck)"
        return false, msg, Set{Int}() 
    end

    # Check that waiting nodes are inserted correctly with respect to time
    activeTime = vehicleSchedule.activeTimeWindow.endTime - vehicleSchedule.activeTimeWindow.startTime
    totalTime = 0
    for idx in 1:length(route)-1
        if route[idx].activity.activityType == WAITING
            totalTime += route[idx].endOfServiceTime - route[idx].startOfServiceTime
        elseif (route[idx].activity.activityType == PICKUP) || (route[idx].activity.activityType == DROPOFF)
            totalTime += serviceTimes[route[idx].activity.mobilityType]
        end

        totalTime += time[route[idx].activity.id,route[idx+1].activity.id]
    end

    if totalTime != activeTime
        msg = "ROUTE INFEASIBLE: Total time based on waiting nodes $(totalTime) is incorrect compared to active time $(activeTime) for vehicle $(vehicle.id)"
        return false, msg, Set{Int}()
    end
    
   
    return true, "", hasBeenServiced
    
end



end 