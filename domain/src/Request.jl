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
    callTime::Int # The time the reqeust is received (minutes after midnight)
    pickupTimeWindow::TimeWindow # Time window for pickup
    deliveryTimeWindow::TimeWindow # Time window for delivery 
    pickupLocation::Location # Pickup location
    dropOffTimeWindow::Location # Delivery location 
    maximumRideTime::Int # Maximum ride time in minutes 
end



end 