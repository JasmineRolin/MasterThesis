module Enums 

export RequestType,PICKUP_REQUEST,DROPOFF_REQUEST
export MobilityType,WALKING,WHEELCHAIR
export ActivityType, PICKUP, DROPOFF, WAITING, DEPOT 

#==
 Enum that describes activity type
==# 
@enum ActivityType begin 
    PICKUP = 0
    DROPOFF = 1
    WAITING = 2
    DEPOT = 3
end

#==
 Allowed delay/early arrival
==#
MAX_DELAY = 15
MAX_EARLY_ARRIVAL = 5

#==
 Enum that describes activity type
==#
@enum RequestType begin
    PICKUP_REQUEST = 0
    DROPOFF_REQUEST = 1
end 

#==
 Enum that describes customer type
==# 
@enum MobilityType begin 
    WALKING = 0
    WHEELCHAIR = 1
end


end 