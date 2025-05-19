module Activities

using ..TimeWindows, ..Locations, ..Enums

export Activity,findCorrespondingId,findLoadOfActivity, copyActivity

mutable struct Activity 
    id::Int 
    requestId::Int 
    activityType::ActivityType
    location::Location 
    timeWindow::TimeWindow

    function Activity()
        new(0, 0, PICKUP, Location("",0,0), TimeWindow(0,0))
    end

    function Activity(id::Int, requestId::Int, activityType::ActivityType, location::Location, timeWindow::TimeWindow)
        new(id, requestId, activityType, location, timeWindow)
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

function copyActivity(a::Activity)
    return Activity(
        a.id,
        a.requestId,
        a.activityType,  # Assuming this is immutable (e.g. enum-like)
        copyLocation(a.location),
        copyTimewindow(a.timeWindow)
    )
end

end