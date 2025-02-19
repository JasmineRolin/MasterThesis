module Scenarios 

using ..Requests, ..Vehicles, ..TimeWindows

export Scenario 

struct Scenario 
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
end 


end