module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule, findPositionOfRequest,isVehicleScheduleEmpty

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float64
    totalTime::Int
    totalCost::Float64 
    totalIdleTime::Int
    numberOfWalking::Vector{Int}
    numberOfWheelchair::Vector{Int}


    # Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create route with depots
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime,WALKING)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime,WALKING)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], vehicle.availableTimeWindow, 0.0, 0, 0.0,0, Int[0,0], Int[0,0]) 

    end

    function VehicleSchedule(vehicle::Vehicle, route::Vector{ActivityAssignment} )
        return new(vehicle, route, vehicle.availableTimeWindow, 0.0, 0, 0.0,0, Int[], Int[]) 
    end

    function VehicleSchedule()
        return new(Vehicle(), [], TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[], Int[])
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
    if length(vehicleSchedule.route) == 2 && vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[2].activity.activityType == DEPOT
       return true 
    end

    if all(a -> a.activity.activityType == WAITING, vehicleSchedule.route[2:end-1])
        return true
    end

    return false
end

end