module Scenarios 

using ..Requests, ..Vehicles, ..TimeWindows, ..Grids, ..Locations

export Scenario, copyScenario

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

    # All-args constructor for anticipation + grid
    function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Int, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict,taxiParameter::Float64, nExpected::Int, taxiParameterExpected::Float64, nFixed::Int, grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location})
    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots, taxiParameter, nExpected, taxiParameterExpected, nFixed,grid,depotLocations)
    end

     # All-args constructor for anticipation and not grid
     function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Int, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict,taxiParameter::Float64, nExpected::Int, taxiParameterExpected::Float64, nFixed::Int)
        grid = Grid()
        depotLocations = Dict{Tuple{Int,Int},Location}() 
    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots, taxiParameter, nExpected, taxiParameterExpected, nFixed,grid,depotLocations)
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

    # All-args constructor for grid and non-anticipation
    function Scenario(name::String,requests::Vector{Request}, onlineRequests::Vector{Request}, offlineRequests::Vector{Request}, 
        serviceTimes::Int, vehicles::Vector{Vehicle}, vehicleCostPrHour::Float64, vehicleStartUpCost::Float64, planningPeriod::TimeWindow, 
        bufferTime::Int, maximumDriveTimePercent::Int, minimumMaximumDriveTime::Int, distance::Array{Float64, 2}, time::Array{Int, 2}, 
        nDepots::Int, depots::Dict,taxiParameter::Float64,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location})

        nExpected = 0
        nFixed = length(requests)
        taxiParameterExpected = 0.0

    return new(name,requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost, 
        planningPeriod, bufferTime, maximumDriveTimePercent, minimumMaximumDriveTime, distance, time, nDepots, depots, taxiParameter, nExpected, taxiParameterExpected, nFixed,grid,depotLocations)
    end

    # No-args constructor
    function Scenario()
        return Scenario("",Vector{Request}(), Vector{Request}(), Vector{Request}(), 0, Vector{Vehicle}(), 0.0, 0.0, TimeWindow(0, 0), 0, 0, 0,zeros(Float64,0,0),zeros(Int,0,0), 0, Dict(),0.0,0,0.0,0,Grid(),Dict{Tuple{Int,Int},Location}())
    end

end 

function copyDictOfLocations(d::Dict{Tuple{Int, Int}, Location})
    return Dict(k => copyLocation(v) for (k, v) in d)
end

function copyScenario(s::Scenario)
    return Scenario(
        s.name,
        [copyRequest(r) for r in s.requests],
        [copyRequest(r) for r in s.onlineRequests],
        [copyRequest(r) for r in s.offlineRequests],
        s.serviceTimes,
        [copyVehicle(v) for v in s.vehicles],
        s.vehicleCostPrHour,
        s.vehicleStartUpCost,
        copyTimewindow(s.planningPeriod),
        s.bufferTime,
        s.maximumDriveTimePercent,
        s.minimumMaximumDriveTime,
        copy(s.distance),  # shallow copy is OK since Float64 is immutable
        copy(s.time),      # shallow copy of Int matrix is safe
        s.nDepots,
        deepcopy(s.depots),  # Assuming simple Dict
        s.taxiParameter,
        s.nExpected,
        s.taxiParameterExpected,
        s.nFixed,
        copyGrid(s.grid),
        copyDictOfLocations(s.depotLocations)
    )
end


end