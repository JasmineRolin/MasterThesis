module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule 

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float64
    totalTime::Float64
    totalCost::Float64 
    numberOfWalking::Vector{Int}
    numberOfWheelchair::Vector{Int}


    # Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create route with depots
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime)),vehicle,vehicle.availableTimeWindow.startTime,vehicle.availableTimeWindow.startTime)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime)),vehicle,vehicle.availableTimeWindow.endTime,vehicle.availableTimeWindow.endTime)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(0, 0), 0.0, 0.0, 0.0, Int[0,0], Int[0,0]) 

    end

end 



end