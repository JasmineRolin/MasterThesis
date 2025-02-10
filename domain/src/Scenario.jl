module Scenarios 

using ..Requests, ..Vehicles, ..TimeWindows

export Scenario 

struct Scenario 
    requests::Vector{Request}
    vehicles::Vector{Vehicle}
    vehicleCostPrHour::Float32
    vehicleStartUpCost::Float32 
    serviceTimes::Dict # Minutes 
    planningPeriod::TimeWindow # Minutes after midnight
end 


end