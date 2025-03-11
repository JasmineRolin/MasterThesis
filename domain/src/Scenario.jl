module Scenarios 

using ..Requests, ..Vehicles, ..TimeWindows

export Scenario 

struct Scenario 
    name::String 
    requests::Vector{Request}
    onlineRequests::Vector{Request}
    offlineRequests::Vector{Request}
    serviceTimes::Dict # Minutes 
    vehicles::Vector{Vehicle}
    vehicleCostPrHour::Float64
    vehicleStartUpCost::Float64 
    planningPeriod::TimeWindow # Minutes after midnight
    bufferTime::Int # Latest call time for a request in minutes
    maximumDriveTimePercent::Int # Percent of direct drive time to find maximum ride time
    minimumMaximumDriveTime::Int # Minimum duration in minutes of maximum drive time 
    distance::Array{Float64, 2}
    time::Array{Int, 2}
    nDepots::Int
    depots::Dict

    # All-args constructor
    function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Dict, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict)
    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots)
    end

    # No-args constructor
    function Scenario()
        return Scenario("",Vector{Request}(), Vector{Request}(), Vector{Request}(), Dict(), Vector{Vehicle}(), 0.0, 0.0, TimeWindow(0, 0), 0, 0, 0,zeros(Float64,0,0),zeros(Int,0,0), 0, Dict())
    end

end 


end