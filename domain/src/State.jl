module State 

using ..Request,..VehicleLocation,..Solution

export State 

mutable struct State 
    requests::Vector{Request}
    vehicleLocations::Vector{VehicleLocation}
    eventTime::Int
    solution::Solution
 
end 


end