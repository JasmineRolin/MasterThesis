module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule
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
    numberOfWheelchair::Vector{Int}


    # Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create route with depots
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.endTime), 0.0, 0, 0.0,0, Int[0,0], Int[0,0]) 
    end

    function VehicleSchedule(vehicle::Vehicle, route::Vector{ActivityAssignment} )
        return new(vehicle, route, TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[], Int[]) 
    end

    function VehicleSchedule()
        return new(Vehicle(), [], TimeWindow(0, 0), 0.0, 0, 0.0,0, Int[], Int[])
    end 

    function VehicleSchedule(vehicle::Vehicle, route::Vector{ActivityAssignment}, activeTimeWindow::TimeWindow, totalDistance::Float64, totalTime::Int, totalCost::Float64, totalIdleTime::Int, numberOfWalking::Vector{Int}, numberOfWheelchair::Vector{Int})
        return new(vehicle, route, activeTimeWindow, totalDistance, totalTime, totalCost, totalIdleTime, numberOfWalking, numberOfWheelchair)
    end

end 

function copyVehicleSchedule(original::VehicleSchedule)
    return VehicleSchedule(
        original.vehicle,  # Assuming Vehicle is immutable or already deeply copied
        deepcopy(original.route),
        deepcopy(original.activeTimeWindow),
        original.totalDistance,
        original.totalTime,
        original.totalCost,
        original.totalIdleTime,
        deepcopy(original.numberOfWalking),
        deepcopy(original.numberOfWheelchair)
    )
end


end

