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
        for activityAssignment in vehicleSchedule.activityAssignments

            request = scenario.requests[activityAssignment.activity.requestId]
            
            if request.id == event.id
                continue
            end

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
 Inital insertion of event
==#
function onlineInsertion(solution::Solution, event::Request, scenario::Scenario)

    state = ALNSState(Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Int}(),Vector{Int}(),solution,solution,[event.id],Vector{Int}(),0)
    regretInsertion(state,scenario)

    return state.currentSolution, state.requestBank

end

#==
 Run online algorithm
==#
function onlineAlgorithm(currentState::State, requestBank::Vector{Int}, scenario::Scenario, destroyMethods::Vector{GenericMethod}, repairMethods::Vector{GenericMethod})

    event, oldSolution = currentState.event, currentState.solution

    # Do intitial insertion
    println("HERE1")
    initialSolution, newrequestBankOnline = onlineInsertion(oldSolution,event,scenario)
    append!(requestBank,newrequestBankOnline)
    println("Solution after simple insertion")
    printSolution(initialSolution,printRouteHorizontal)
    currentOnlineRequest = Request[]
    for r in scenario.onlineRequests
        if r.id == event.id
            push!(currentOnlineRequest, r)
            break
        end
        push!(currentOnlineRequest, r)
    end
    allRequestsCurrently = scenario.offlineRequests
    for r in currentOnlineRequest
        push!(allRequestsCurrently, r)
    end
    feasible, msg = checkSolutionFeasibility(scenario,initialSolution,allRequestsCurrently)
    println("TESSSST")
    println(feasible)
    println(msg)
    println(requestBank)

    

    # Run ALNS # TODO ensure right input
    println("HERE2")

    finalSolution,requestBank,specification,KPIs = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters2.json",stage = "online",initialSolution =  initialSolution, requestBank = requestBank)
    println("HERE3")
    # Update time window for event
    updateTimeWindowsOnlineOne!(finalSolution,event,scenario)

    return finalSolution,requestBank,specification,KPIs

end

end