module Requests 

using ..TimeWindows, ..Locations

export Request, RequestType,MobilityType,PICKUP,DROPOFF,WALKING,WHEELCHAIR

#==
 Enum that describes activity type
==#
@enum RequestType begin
    PICKUP = 0
    DROPOFF = 1
end 

#==
 Enum that describes customer type
==# 
@enum MobilityType begin 
    WALKING = 0
    WHEELCHAIR = 1
end


#== 
 Struct that defines request 
==#
struct Request
    id::Int 
    requestType::RequestType
    mobilityType::MobilityType
    load::Int 
    callTime::Int # The time the reqeust is received (minutes after midnight)
    dropOffLocation::Location 
    pickupLocation::Location # Pickup location
    pickuopTimeWindow::TimeWindow # Time window for drop off 
    dropOffTimeWindow::TimeWindow # Delivery location 
    maximumRideTime::Int # Maximum ride time in minutes 
end



end 