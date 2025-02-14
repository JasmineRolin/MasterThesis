module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows, ..Activities, ..Enums

export VehicleSchedule 

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float32
    totalCost::Float32 
    numberOfWalking::Vector{Int} # number of WALKING customers on vehicle after servicing node idx
    numberOfWheelchair::Vector{Int} # number of WHEELCHAIR customers on vehicle after servicing node idx

    # Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create route with depots
        # TODO: set the correct start and end of service for depots (according to availableTimeWindow)
        startDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(0,0)),vehicle,0,0)
        endDepot = ActivityAssignment(Activity(vehicle.depotId,-1,DEPOT,WALKING,vehicle.depotLocation,TimeWindow(24*60,24*60)),vehicle,24*60,24*60)

        # Create empty VehicleSchedule objects
        return new(vehicle, [startDepot,endDepot], TimeWindow(0, 0), 0.0, 0.0, [0,0], [0,0]) 
    end

end 



end