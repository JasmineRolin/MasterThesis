module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule, findPositionOfRequest,isVehicleScheduleEmpty
export copyVehicleSchedule 


mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float64
    totalTime::Int
    totalCost::Float64 
    totalIdleTime::Int
    numberOfWalking::Vector{Int}

    # Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create route with depots
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime), 0.0, 0, 0.0,0, Int[0,0]) 
    end

    function VehicleSchedule(vehicle::Vehicle,emptyRoute::Bool)
        if emptyRoute
            return new(vehicle, [], TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime), 0.0, 0, 0.0,0, Vector{Int}()) 
        end
        
        # Create route with depots
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime), 0.0, 0, 0.0,0, Int[0,0]) 
    end

    function VehicleSchedule(vehicle::Vehicle, route::Vector{ActivityAssignment} )
        return new(vehicle, route, TimeWindow(route[1].startOfServiceTime,vehicle.availableTimeWindow.endTime), 0.0, 0, 0.0,0, Int[]) 
    end

    function VehicleSchedule()
        return new(Vehicle(), [], TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[])
    end 

    function VehicleSchedule(vehicle::Vehicle, route::Vector{ActivityAssignment}, activeTimeWindow::TimeWindow, totalDistance::Float64, totalTime::Int, totalCost::Float64, totalIdleTime::Int, numberOfWalking::Vector{Int})
        return new(vehicle, route, activeTimeWindow, totalDistance, totalTime, totalCost, totalIdleTime, numberOfWalking)
    end

end 

#==
 Method to determine whether vehicle schedule contains request 
==#
function findPositionOfRequest(vehicleSchedule::VehicleSchedule, requestId::Int)::Tuple{Int,Int}
    pickupIdx, dropoffIdx = -1, -1

    for (idx, assignment) in enumerate(vehicleSchedule.route)
        activity = assignment.activity
        if activity.requestId == requestId
            if activity.activityType == PICKUP
                pickupIdx = idx
            elseif activity.activityType == DROPOFF
                return (pickupIdx, idx)  # Early return once both are found
            end
        end
    end

    return (pickupIdx, dropoffIdx)
end

#==
 Method to check if vehicle schedule is empty 
==#
function isVehicleScheduleEmpty(vehicleSchedule::VehicleSchedule)
    if vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[end].activity.activityType == DEPOT
        if length(vehicleSchedule.route) == 2
            return true
        elseif all(a -> (a.activity.activityType == WAITING), vehicleSchedule.route[2:end-1])
            return true
        end
    end

    return false
end

#==
 Method to copy vehicle schedule
==#
function copyVehicleSchedule(vehicleSchedule::VehicleSchedule)
    return VehicleSchedule(
        vehicleSchedule.vehicle,  # Assuming Vehicle is immutable or already deeply copied
        [copyActivityAssignment(assignment) for assignment in vehicleSchedule.route],  # Deep copy of route
        deepcopy(vehicleSchedule.activeTimeWindow),
        vehicleSchedule.totalDistance,
        vehicleSchedule.totalTime,
        vehicleSchedule.totalCost,
        vehicleSchedule.totalIdleTime,
        deepcopy(vehicleSchedule.numberOfWalking),
    )
end

end

