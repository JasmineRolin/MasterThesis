module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule 

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float32
    totalCost::Float32 
    nWalking::Int
    nWheelchair::Int

    #Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create route with depots
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(0,0)),vehicle,0,0)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(24*60,24*60)),vehicle,24*60,24*60)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(0, 0), 0.0, 0.0) 
    end

end 



end