module Requests 

using ..TimeWindows, ..Locations, ..Enums
using ..Activities


export Request
export findTimeWindowOfRequestedPickUpTime, findTimeWindowOfDropOff, findTimeWindowOfRequestedDropOffTime, findTimeWindowOfPickUp
export findMaximumRideTime

#==
 Allowed delay/early arrival
==#
MAX_DELAY = 15
MAX_EARLY_ARRIVAL = 5

#== 
 Struct that defines request 
==#
struct Request
    id::Int 
    requestType::RequestType
    mobilityType::MobilityType
    callTime::Int # The time the request is received (minutes after midnight)
    pickUpActivity::Activity 
    dropOffActivity::Activity 
    directDriveTime::Int # Direct drive time in minutes 
    maximumRideTime::Int # Maximum ride time in minutes 
end


#==
 Method to find time window for requested pick-up time 
==#
function findTimeWindowOfRequestedPickUpTime(requestTime::Int)::TimeWindow
    return TimeWindow(requestTime-MAX_EARLY_ARRIVAL,requestTime + MAX_DELAY)
end

#==
 Method to find time window for drop-off when PICKUP request  
==#
function findTimeWindowOfDropOff(pickUpTimeWindow::TimeWindow, directDriveTime::Int, maximumRideTime::Int)::TimeWindow
    return TimeWindow(pickUpTimeWindow.startTime + directDriveTime, pickUpTimeWindow.endTime + maximumRideTime)
end

#==
 Method to find time window for requested drop-off time 
==#
function findTimeWindowOfRequestedDropOffTime(requestTime::Int)::TimeWindow
    return TimeWindow(requestTime-MAX_DELAY,requestTime + MAX_EARLY_ARRIVAL)
end

#==
 Method to find time window for picku-up when DROPOFF request  
==#
function findTimeWindowOfPickUp(dropOffTimeWindow::TimeWindow, directDriveTime::Int, maximumRideTime::Int)::TimeWindow
    return TimeWindow(dropOffTimeWindow.startTime - maximumRideTime, dropOffTimeWindow.endTime - directDriveTime)
end

#==
 Find maximum drive time  
==#
function findMaximumRideTime(directDriveTime::Int,maximumDriveTimePercent::Int,minimumMaximumDriveTime)::Int 
    
    percent = maximumDriveTimePercent/100.0

    return Int(max(directDriveTime + directDriveTime*percent,minimumMaximumDriveTime))
end


end 