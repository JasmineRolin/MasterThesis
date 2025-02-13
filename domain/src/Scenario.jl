module Scenarios 

using ..Requests, ..Vehicles, ..TimeWindows

export Scenario 

struct Scenario 
    requests::Vector{Request}
    onlineRequests::Vector{Request}
    offlineRequests::Vector{Request}
    serviceTimes::Dict # Minutes 
    vehicles::Vector{Vehicle}
    vehicleCostPrHour::Float32
    vehicleStartUpCost::Float32 
    planningPeriod::TimeWindow # Minutes after midnight
    bufferTime::Int # Latest call time for a request in minutes
    maximumDriveTimePercent::Int # Percent of direct drive time to find maximum ride time
    minimumMaximumDriveTime::Int # Minimum duration in minutes of maximum drive time 
    distance::Vector{Vector{Int}}
    time::Vector{Vector{Int}}
end 


end