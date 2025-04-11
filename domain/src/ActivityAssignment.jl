module ActivityAssignments 

using ..Requests, ..Vehicles, ..Activities, ..Enums

export ActivityAssignment, copyActivityAssignment

mutable struct ActivityAssignment
    activity::Activity 
    vehicle::Vehicle 
    startOfServiceTime::Int 
    endOfServiceTime::Int 

    function ActivityAssignment(activity::Activity, vehicle::Vehicle, startOfServiceTime::Int, endOfServiceTime::Int)
        return new(activity, vehicle, startOfServiceTime, endOfServiceTime)
    end
end

#==
 Method to copy activity assignment 
==#
function copyActivityAssignment(activityAssignment::ActivityAssignment)
    # Copy activity if necesarry
    if activityAssignment.activity.activityType == DEPOT || activityAssignment.activity.activityType == WAITING 
        activity = deepcopy(activityAssignment.activity)
    else
        activity = activityAssignment.activity
    end

    # Create a new ActivityAssignment object with the same properties
    return ActivityAssignment(
        activity, 
        activityAssignment.vehicle, 
        activityAssignment.startOfServiceTime, 
        activityAssignment.endOfServiceTime
    )
end

end