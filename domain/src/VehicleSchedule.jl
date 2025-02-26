module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule, findPositionOfRequest

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
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[0,0], Int[0,0]) 

    end

    function VehicleSchedule(vehicle::Vehicle, route::Vector{ActivityAssignment} )
        return new(vehicle, route, TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[], Int[]) 
    end

    function VehicleSchedule()
        return new(Vehicle(), [], TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[], Int[])
    end 

end 

#==
 Method to determine whether vehicle schedule contains request 
==#
function findPositionOfRequest(vehicleSchedule::VehicleSchedule, requestId::Int)::Tuple{Int,Int}
    pos = (-1,-1)
    for (idx,activityAssignment) in enumerate(vehicleSchedule.route)
        if activityAssignment.activity.requestId == requestId && activityAssignment.activity.activityType == PICKUP
            pos[1] = idx
        elseif activityAssignment.activity.requestId == requestId && activityAssignment.activity.activityType == DROPOFF
            pos[2] = idx
            return idx
        end
    end

    return pos
end


end