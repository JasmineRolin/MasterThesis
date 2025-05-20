module Locations 

export Location, copyLocation

mutable struct Location 
    name::String 
    lat::Float64
    long::Float64
end

function copyLocation(loc::Location)
    return Location(loc.name, loc.lat, loc.long)
end

end