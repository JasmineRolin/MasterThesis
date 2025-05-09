module Solutions 

using ..VehicleSchedules 
using ..Scenarios

export Solution,copySolution

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float64
    nTaxi::Int
    totalRideTime::Int
    totalDistance::Float64
    totalIdleTime::Int
    nTaxiExpected::Int

    # Constructor
    function Solution(scenario::Scenario)
        vehicleSchedules = [VehicleSchedule(vehicle) for vehicle in scenario.vehicles]
        return new(vehicleSchedules, 0.0, 0, 0, 0, 0, 0)
    end

    # All-argument constructor
    function Solution(vehicleSchedules::Vector{VehicleSchedule}, totalCost::Float64, nTaxi::Int, totalRideTime::Int, totalDistance::Float64, totalIdleTime::Int, nTaxiExpected::Int)
        new(vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, totalIdleTime, nTaxiExpected)
    end

    # All-argument constructor except nTaxiExpected
    function Solution(vehicleSchedules::Vector{VehicleSchedule}, totalCost::Float64, nTaxi::Int, totalRideTime::Int, totalDistance::Float64, totalIdleTime::Int)
        new(vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, totalIdleTime, 0)
    end

end

#==
 Method to copy solution 
==#
function copySolution(solution::Solution)
    # Create a deep copy of the vehicle schedules
    vehicleSchedulesCopy = [copyVehicleSchedule(schedule) for schedule in solution.vehicleSchedules]
    
    # Create a new Solution object with the copied vehicle schedules
    return Solution(vehicleSchedulesCopy, solution.totalCost, solution.nTaxi, solution.totalRideTime, solution.totalDistance, solution.totalIdleTime, solution.nTaxiExpected)
end 

end