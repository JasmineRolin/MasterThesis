module onlineSolutionUtils

using domain
using alns
using utils

export updateTimeWindowsOnlineAll!, onlineAlgorithm

#==
 Allowed delay/early arrival
==#
MAX_DELAY = 15
MAX_EARLY_ARRIVAL = 5


#==
 Update time windows for all requests in solution
==#
# TODO: jas - hvad er forskellen ? 
function updateTimeWindowsOnlineAll!(solution::Solution,scenario::Scenario)

    # Remember start of service
    requestStartOfService = Dict{Int,Int}()

    for vehicleSchedule in solution.vehicleSchedules
        for activityAssignment in vehicleSchedule.activityAssignments

            request = scenario.requests[activityAssignment.activity.requestId]
            
            # Update time windows for pick-up
            if activityAssignment.activity.activityType == PICKUP
                requestStartOfService[activityAssignment.activity.requestId] = activityAssignment.startOfServiceTime
                activityAssignment.activity.timeWindow = TimeWindow(activityAssignment.startOfServiceTime-MAX_EARLY_ARRIVAL,activityAssignment.startOfServiceTime+MAX_DELAY)
            # Update time windows for drop-off for pick-up requests
            elseif activityAssignment.activity.activityType == DROPOFF && request.requestType == PICKUP_REQUEST
                activityAssignment.activity.timeWindow = TimeWindow(activityAssignment.startOfServiceTime-MAX_EARLY_ARRIVAL+request.directDriveTime,activityAssignment.startOfServiceTime+MAX_DELAY+request.maximumRideTime)
            end

        end
    end


end


#==
 Update time windows for one new request in solution
==#
function updateTimeWindowsOnlineOne!(solution::Solution,event::Request,scenario::Scenario)

    # Remember start of service
    requestStartOfService = Dict{Int,Int}()

    for vehicleSchedule in solution.vehicleSchedules
        for activityAssignment in vehicleSchedule.route
            
            if activityAssignment.activity.requestId > 0 && activityAssignment.activity.requestId == event.id
                continue
            end

            # Update time windows for pick-up
            if activityAssignment.activity.activityType == PICKUP
                requestStartOfService[activityAssignment.activity.requestId] = activityAssignment.startOfServiceTime
                activityAssignment.activity.timeWindow = TimeWindow(activityAssignment.startOfServiceTime-MAX_EARLY_ARRIVAL,activityAssignment.startOfServiceTime+MAX_DELAY)
            # Update time windows for drop-off for pick-up requests
            elseif activityAssignment.activity.activityType == DROPOFF && scenario.requests[activityAssignment.activity.requestId] == PICKUP_REQUEST
                activityAssignment.activity.timeWindow = TimeWindow(activityAssignment.startOfServiceTime-MAX_EARLY_ARRIVAL+request.directDriveTime,activityAssignment.startOfServiceTime+MAX_DELAY+request.maximumRideTime)
            end

        end
    end


end

#==
 Inital insertion of event
==#
function onlineInsertion(solution::Solution, event::Request, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())

    state = ALNSState(Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Int}(),Vector{Int}(),solution,solution,[event.id],Vector{Int}(),0)
    regretInsertion(state,scenario,visitedRoute=visitedRoute)

    return state.requestBank

end

#==
 Run online algorithm
==#
function onlineAlgorithm(currentState::State, requestBank::Vector{Int}, scenario::Scenario, destroyMethods::Vector{GenericMethod}, repairMethods::Vector{GenericMethod})

    event, currentSolution, totalNTaxi = currentState.event, deepcopy(currentState.solution), currentState.totalNTaxi

    # Do intitial insertion
    newrequestBankOnline = onlineInsertion(currentSolution,event,scenario,visitedRoute = currentState.visitedRoute)

    # Check feasibility
    # currentState.solution = initialSolution
    feasible, msg = checkSolutionFeasibilityOnline(scenario,currentSolution, event, currentState.visitedRoute,totalNTaxi)
    if !feasible
        throw(msg)
    end

    # Run ALNS
    finalSolution,finalOnlineRequestBank,_,_ = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters2.json",stage = "online",initialSolution =  currentSolution, requestBank = newrequestBankOnline, event = event, alreadyRejected =  totalNTaxi, visitedRoute = currentState.visitedRoute,displayPlots = false, savePlots = false)
    append!(requestBank,finalOnlineRequestBank)

    feasible, msg = checkSolutionFeasibilityOnline(scenario,finalSolution, event, currentState.visitedRoute,totalNTaxi)
    if !feasible
        println(" WRONG AFTER ALNS")
        printSolution(finalSolution,printRouteHorizontal)
        throw(msg)
    end

    # Update time window for event
    updateTimeWindowsOnlineOne!(finalSolution,event,scenario)

    return finalSolution,requestBank

end

end