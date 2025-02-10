module RequestAssignments 

using ..Requests, ..Vehicles

export RequestAssignment 

mutable struct RequestAssignment
    request::Request 
    vehicle::Vehicle 
    startOfServiceTime::Int 
    endOfServiceTime::Int 
end


end