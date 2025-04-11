module onlineSolutionUtils

using domain
using alns
using utils

export updateTimeWindowsOnline!, onlineAlgorithm

#==
 Allowed delay/early arrival
==#
global MAX_DELAY_ONLINE = 15
global MAX_EARLY_ARRIVAL_ONLINE = 5


#==
 Update time windows for all requests in solution
==#
function updateTimeWindowsOnline!(solution::Solution,scenario::Scenario;searchForEvent::Bool=false,eventId::Int=-10)

    for vehicleSchedule in solution.vehicleSchedules
        for activityAssignment in vehicleSchedule.route
            # Retrieve request id
            requestId = activityAssignment.activity.requestId

            # Skip non-request activities and other requests if single request needs to be updated
            if requestId < 1 || (searchForEvent && requestId != eventId)
                continue
            end

            request = scenario.requests[requestId]
            
            # Update time windows for pick-up
            if activityAssignment.activity.activityType == PICKUP
                request.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(activityAssignment.startOfServiceTime,MAX_DELAY_ONLINE,MAX_EARLY_ARRIVAL_ONLINE)
            # Update time windows for drop-off 
            elseif activityAssignment.activity.activityType == DROPOFF
                request.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request.pickUpActivity.timeWindow,request.directDriveTime,request.maximumRideTime)

                # Return if we are only updating single event 
                if requestId == eventId 
                    return 
                end
            end
           
        end
    end


end


#==
 Inital insertion of event
==#
function onlineInsertion(solution::Solution, event::Request, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())

    state = ALNSState(Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Float64}(),Vector{Int}(),Vector{Int}(),solution,[event.id],solution,[event.id],Vector{Int}(),0)
    regretInsertion(state,scenario,visitedRoute=visitedRoute)

    return state.requestBank

end

#==
 Run online algorithm
==#
function onlineAlgorithm(currentState::State, requestBank::Vector{Int}, scenario::Scenario, destroyMethods::Vector{GenericMethod}, repairMethods::Vector{GenericMethod})

    # Retrieve info 
    event, currentSolution, totalNTaxi = currentState.event, copySolution(currentState.solution), currentState.totalNTaxi

    # Do intitial insertion
    newRequestBankOnline = onlineInsertion(currentSolution,event,scenario,visitedRoute = currentState.visitedRoute)

    # Run ALNS
    # TODO: set correct parameters for alns 
    finalSolution,finalOnlineRequestBank,_,_ = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters2.json",initialSolution =  currentSolution, requestBank = newRequestBankOnline, event = event, alreadyRejected =  totalNTaxi, visitedRoute = currentState.visitedRoute,displayPlots = false, savePlots = false)
   
    # TODO: remove when alns is stable
    if length(finalOnlineRequestBank) > 1 || (length(finalOnlineRequestBank) == 1 && finalOnlineRequestBank[1] != event.id)
        println("ALNS: FINAL REQUEST BANK IS NOT EMPTY")
        println(finalOnlineRequestBank)
        println("Event: ",event.id)
        printSolution(finalSolution,printRouteHorizontal)
        throw("error")
    end

    append!(requestBank,finalOnlineRequestBank)

    feasible, msg = checkSolutionFeasibilityOnline(scenario,finalSolution, event, currentState.visitedRoute,totalNTaxi)

    # TODO: remove when alns is stable 
    if !feasible
        println("WRONG AFTER ALNS")
        printSolution(finalSolution,printRouteHorizontal)

        println("======================================")
        printSolution(currentSolution,printRouteHorizontal)

        throw(msg)
    end

    # Update time window for event
    updateTimeWindowsOnline!(finalSolution,scenario,searchForEvent=true,eventId = event.id)

    return finalSolution, requestBank

end

end