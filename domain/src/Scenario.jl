module Scenarios 

using ..Requests, ..Vehicles, ..TimeWindows, ..Grids, ..Locations

export Scenario 

struct Scenario 
    name::String 
    requests::Vector{Request}
    onlineRequests::Vector{Request}
    offlineRequests::Vector{Request}
    serviceTimes::Int # Minutes 
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
    taxiParameter::Float64
    nExpected::Int
    taxiParameterExpected::Float64
    nFixed::Int
    grid::Grid
    depotLocations::Dict{Tuple{Int,Int},Location} # possible depot locations in grid 

    # All-args constructor ofr anticipation
    function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Int, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict,taxiParameter::Float64, nExpected::Int, taxiParameterExpected::Float64, nFixed::Int)
    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots, taxiParameter, nExpected, taxiParameterExpected, nFixed)
    end

    # All-args constructor for non-anticipation
    function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Int, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict,taxiParameter::Float64)

        nExpected = 0
        nFixed = length(requests)
        taxiParameterExpected = 0.0

    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots, taxiParameter, nExpected, taxiParameterExpected, nFixed)
    end

    function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Int, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict,taxiParameter::Float64,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location})
    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots, taxiParameter,grid,depotLocations)
    end

    # No-args constructor
    function Scenario()
        return Scenario("",Vector{Request}(), Vector{Request}(), Vector{Request}(), 0, Vector{Vehicle}(), 0.0, 0.0, TimeWindow(0, 0), 0, 0, 0,zeros(Float64,0,0),zeros(Int,0,0), 0, Dict(),0.0,0,0.0,0)
    end

end 


end