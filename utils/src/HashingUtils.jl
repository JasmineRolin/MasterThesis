module HashingUtils

using domain

export hashSolution

function hashSolution(sol::Solution)::String
    # Extract route strings from each vehicle's schedule
    routeStrs = [
        join([activityAssignment.activity.id for activityAssignment in schedule.route], "-")
        for schedule in sol.vehicleSchedules
    ]

    # Sort route strings to make route order irrelevant
    sortedRouteStrs = sort(routeStrs)

    # Join sorted route strings with a pipe
    routesHash = join(sortedRouteStrs, "|")

    # Include relevant KPIs
    kpis = string(sol.totalCost, "", sol.nTaxi, "", sol.totalRideTime, "", round(sol.totalDistance,digits=2), "", sol.totalIdleTime)

    # Final key
    return routesHash * "#" * kpis
end


end