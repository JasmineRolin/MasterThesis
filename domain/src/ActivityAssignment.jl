module ActivityAssignments 

using ..Requests, ..Vehicles, ..Activities, ..Enums

export ActivityAssignment 

mutable struct ActivityAssignment
    activity::Activity 
    vehicle::Vehicle 
    startOfServiceTime::Int 
    endOfServiceTime::Int 
end


end