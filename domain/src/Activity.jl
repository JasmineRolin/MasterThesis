module Activities

using ..TimeWindows, ..Locations, ..Enums

export Activity,findCorrespondingId,findLoadOfActivity

mutable struct Activity 
    id::Int 
    requestId::Int 
    activityType::ActivityType
    mobilityType::MobilityType
    location::Location 
    timeWindow::TimeWindow

    function Activity()
        new(0, 0, PICKUP, WALKING, Location("",0,0), TimeWindow(0,0))
    end

    function Activity(id::Int, requestId::Int, activityType::ActivityType, mobilityType::MobilityType, location::Location, timeWindow::TimeWindow)
        new(id, requestId, activityType, mobilityType, location, timeWindow)
    end
end

#==
 Method to find corresponding activity id for PICKUP/DROPOFF activity
==#
function findCorrespondingId(activity::Activity, nRequests::Int)::Int
    if activity.activityType == PICKUP
        return activity.id + nRequests
    else
        return activity.id - nRequests
    end
end

#==
 Method to return load of activity
==#
function findLoadOfActivity(activity::Activity)::Int
    if activity.activityType == PICKUP
        return 1
    elseif activity.activityType == DROPOFF
        return -1
    end
    
    return 0
end


end