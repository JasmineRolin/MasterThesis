module Requests 

using ..TimeWindows, ..Locations, ..Enums
using ..Activities


export Request
export findTimeWindowOfRequestedPickUpTime, findTimeWindowOfDropOff, findTimeWindowOfRequestedDropOffTime, findTimeWindowOfPickUp
export findMaximumRideTime
export MAX_DELAY, MAX_EARLY_ARRIVAL

#== 
 Struct that defines request 
==#
mutable struct Request
    id::Int 
    requestType::RequestType
    callTime::Int # The time the request is received (minutes after midnight)
    pickUpActivity::Activity 
    dropOffActivity::Activity 
    directDriveTime::Int # Direct drive time in minutes 
    maximumRideTime::Int # Maximum ride time in minutes 

    # Empty constructor
    function Request()
        new(0, PICKUP_REQUEST, 0, Activity(), Activity(), 0, 0)
    end

    function Request(id::Int, requestType::RequestType, callTime::Int, pickUpActivity::Activity, dropOffActivity::Activity, directDriveTime::Int, maximumRideTime::Int)
        new(id, requestType, callTime, pickUpActivity, dropOffActivity, directDriveTime, maximumRideTime)
    end
end


#==
 Method to find time window for requested pick-up time 
==#
function findTimeWindowOfRequestedPickUpTime(requestTime::Int,maxDelay::Int,maxEarlyArrival::Int)::TimeWindow
    return TimeWindow(requestTime - maxEarlyArrival,requestTime + maxDelay)
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
function findTimeWindowOfRequestedDropOffTime(requestTime::Int,maxDelay::Int,maxEarlyArrival::Int)::TimeWindow
    return TimeWindow(requestTime - maxDelay,requestTime + maxEarlyArrival)
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