module Requests 

using Dates, ..TimeWindows, ..Locations

export Request, Activity,CustomerType

#==
 Enum that describes activity type
==#
@enum Activity PICKUP=0 DELIVERY=1

#==
 Enum that describes customer type
==# 
@enum CustomerType WALKING=0 WHEELCHAIR=1


#== 
 Struct that defines request 
==#
struct Request
    id::Int 
    activity::Activity
    customerType::CustomerType
    date::Date # The date where the request happens
    timeReceived::DateTime # The date and time the reqeust is received 
    pickupTimeWindow::TimeWindow # Time window for pickup
    deliveryTimeWindow::TimeWindow # Time window for delivery 
    pickupLocation::Location # Pickup location
    deliveryLocation::Location # Delivery location 
    maximumRideTime::Int # Maximum ride time in minutes 
    numberOfTravellers::Int # Number of travellers including customer 
end



end 