module RequestAssignments 

using ..Requests, ..Vehicles

export RequestAssignment 

struct RequestAssignment
    request::Request 
    vehicle::Vehicle 
    startOfServiceTime::Int 
    endOfServiceTime::Int 
end


end