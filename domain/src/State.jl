module States 

using ..VehicleSchedules 
using ..Scenarios

export State 

mutable struct State 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32 
    nTaxi::Int 
    totalRideTime::Int 
    totalDistance::Int 
    idleTime::Int 

    # Constructor
    function State(scenario::Scenario)
        vehicle_schedules = [VehicleSchedule(vehicle) for vehicle in scenario.vehicles]
        return new(vehicle_schedules, 0.0, 0, 0, 0, 0)
    end
end



end