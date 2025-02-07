module Requests 

using ..TimeWindows, ..Locations

export Request, Activity,CustomerType

#==
 Enum that describes activity type
==#
@enum RequestType PICKUP=0 DELIVERY=1

#==
 Enum that describes customer type
==# 
@enum MobilityType WALKING=0 WHEELCHAIR=1


#== 
 Struct that defines request 
==#
struct Request
    id::Int 
    requestType::RequestType
    mobilityType::MobilityType
    load::Int 
    callTime::Int # The time the reqeust is received (minutes after midnight)
    pickUpLocation::Location 
    dropOffLocation::Location 
    pickupLocation::Location # Pickup location
    pickuopTimeWindow::TimeWindow # Time window for drop off 
    dropOffTimeWindow::Location # Delivery location 
    maximumRideTime::Int # Maximum ride time in minutes 
end



end 