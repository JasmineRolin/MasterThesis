module Solutions 

using ..VehicleSchedules 
using ..Scenarios

export Solution

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float64
    nTaxi::Int
    totalRideTime::Int
    totalDistance::Float64
    totalIdleTime::Int

    # Constructor
    function Solution(scenario::Scenario)
        vehicleSchedules = [VehicleSchedule(vehicle) for vehicle in scenario.vehicles]
        return new(vehicleSchedules, 0.0, 0, 0, 0, 0)
    end

    # All-argument constructor
    function Solution(vehicleSchedules::Vector{VehicleSchedule}, totalCost::Float64, nTaxi::Int, totalRideTime::Int, totalDistance::Int, totalIdleTime::Int)
        new(vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, totalIdleTime)
    end
end

end