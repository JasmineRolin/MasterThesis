module Activities

using ..TimeWindows, ..Locations, ..Enums

export Activity,findCorrespondingId,findLoadOfActivity

struct Activity 
    id::Int 
    requestId::Int 
    activityType::ActivityType
    mobilityType::MobilityType
    location::Location 
    timeWindow::TimeWindow
end

#==
 Method to find corresponding activity id for PICKUP/DROPOFF activity
==#
function findCorrespondingId(activity::Activity, nRequests::Int)::Int
    if activity.activityType == ActivityType.PICKUP
        return activity.id + nRequests
    else
        return activity.id - nRequests
    end
end

#==
 Method to return load of activity
==#
function findLoadOfActivity(activity::Activity)::Int
    if activity.activityType == ActivityType.PICKUP
        return 1
    elseif activity.activityType == ActivityType.DROPOFF
        return -1
    end
    
    return 0
end


end