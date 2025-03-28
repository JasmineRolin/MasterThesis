module Enums 

export RequestType,PICKUP_REQUEST,DROPOFF_REQUEST
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
    PICKUP_REQUEST = 1
    DROPOFF_REQUEST = 0
end 



end 