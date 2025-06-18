
module SimulationFramework

using utils
using domain
using offlinesolution
using onlinesolution
using alns
using waitingstrategies
using StatsPlots
using CSV, DataFrames


include("../../decisionstrategies/anticipation.jl")

export simulateScenario

struct Event 
    id::Int
    callTime::Int
    request::Request
end

# ------
# Function to simulate a scenario
# ------
function getTimeAsString(callTime::Int)
    # Find time string 
    hours = div(callTime, 60)
    if hours < 10 
        hours = string("0",hours)
    else 
        hours = string(hours)
    end

    minutes = mod(callTime, 60)
    if minutes < 10 
        minutes = string("0",minutes)
    else 
        minutes = string(minutes)
    end

    timeString = hours*":"*minutes

    return timeString
end

# ------
# Function to update current state if entire route has been served and vehicle is not available anymore
# ------
function updateCurrentScheduleNotAvailableAnymore!(currentState::State,schedule::VehicleSchedule,vehicle::Int)

    # Update visited route
    for i in 1:length(schedule.route)
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end
   
    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update schedule with only end  depot for unavailable vehicle 
    currentSchedule.route = [schedule.route[end]]
    currentSchedule.activeTimeWindow.startTime = schedule.route[end].endOfServiceTime
    currentSchedule.activeTimeWindow.endTime = schedule.route[end].endOfServiceTime

    # Update current state
    currentState.solution.totalDistance -= currentSchedule.totalDistance
    currentState.solution.totalCost -= currentSchedule.totalCost
    currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime
    currentState.solution.totalRideTime -= currentSchedule.totalTime

    # Update KPIs
    currentSchedule.totalDistance = 0.0
    currentSchedule.totalCost = 0.0
    currentSchedule.totalIdleTime = 0
    currentSchedule.totalTime = 0
    currentSchedule.numberOfWalking = [0] 

    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1 

    return idx, currentSchedule.activeTimeWindow.startTime
end

# ------
# Function to update current state if entire route has been served and vehicle is still available
# ------
function updateCurrentScheduleRouteCompleted!(currentState::State,schedule::VehicleSchedule,vehicle::Int)

     # Update visited route
     for i in 1:length(schedule.route)
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end
   
    # Retrieve empty schedule and update it 
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update KPIs of current state pre  
    currentState.solution.totalDistance -= currentSchedule.totalDistance
    currentState.solution.totalRideTime -= currentSchedule.totalTime
    currentState.solution.totalCost -= currentSchedule.totalCost
    currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime


    arrivalAtDepot = schedule.route[end].startOfServiceTime
    endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime

    # Create waiting activity to replace depot activity
    waitingActivityCompletedRoute = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), schedule.vehicle,arrivalAtDepot,endOfAvailableTimeWindow)

    # Update schedule with only  depots for  vehicle 
    currentSchedule.route = [waitingActivityCompletedRoute,currentSchedule.route[end]]
    currentSchedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
    currentSchedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
    currentSchedule.activeTimeWindow.startTime = arrivalAtDepot
    currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow

    # Update KPIs
    currentSchedule.totalDistance = 0.0
    currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
    currentSchedule.totalCost = 0.0
    currentSchedule.totalIdleTime = endOfAvailableTimeWindow - arrivalAtDepot
    currentSchedule.numberOfWalking = [0,0]

    # Update current state pro
    currentState.solution.totalDistance += currentSchedule.totalDistance
    currentState.solution.totalRideTime += currentSchedule.totalTime
    currentState.solution.totalCost += currentSchedule.totalCost
    currentState.solution.totalIdleTime += currentSchedule.totalIdleTime


    # Index to split route into current and completed route 
    idx = length(schedule.route) - 1

    return idx, arrivalAtDepot
end

# ------
# Function to update current state if vehicle is not available yet or has not started service yet
# ------
function updateCurrentScheduleNotAvailableYet(schedule::VehicleSchedule,currentState::State,vehicle::Int)
    # update current schedule 
    currentState.solution.vehicleSchedules[vehicle] = schedule

    return 0, 0
end


# ------
# Function to update current state if vehicle has not been assigned yet
# ------
function updateCurrentScheduleNoAssignement!(vehicle::Int,currentTime::Int,currentState::State)
    # Retrieve empty schedule and update it
    currentSchedule = currentState.solution.vehicleSchedules[vehicle]

    # Update active time window 
    currentSchedule.activeTimeWindow.endTime = currentTime
    currentSchedule.activeTimeWindow.startTime = currentTime

    # Update depots (start and end)
    currentSchedule.route[1].startOfServiceTime = currentTime
    currentSchedule.route[1].endOfServiceTime = currentTime

    # index to split route into current and completed route
    idx = 0

    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle has visited some customers 
# ------
function updateCurrentScheduleAtSplit!(scenario::Scenario,schedule::VehicleSchedule,vehicle::Int,currentState::State,idx::Int,currentTime::Int)
    
    # Update visited route
    for i in 1:idx
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end


    # Split waiting activity if it is next activity 
    if schedule.route[idx+1].activity.activityType == WAITING && schedule.route[idx+1].startOfServiceTime < currentTime
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        currentState.solution.totalDistance -= currentSchedule.totalDistance
        currentState.solution.totalRideTime -= currentSchedule.totalTime
        currentState.solution.totalCost -= currentSchedule.totalCost
        currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime

        waitingActivity = schedule.route[idx+1]

        # Create new waiting activity 
        waitingActivityNew = ActivityAssignment(Activity(waitingActivity.activity.id,-1,WAITING, waitingActivity.activity.location,TimeWindow(waitingActivity.startOfServiceTime,currentTime)), schedule.vehicle,waitingActivity.startOfServiceTime,currentTime)

        # Update existing waiting activity 
        waitingActivity.startOfServiceTime = currentTime
        waitingActivity.activity.timeWindow.startTime = currentTime

        # Update route of schedule 
        schedule.route = vcat(schedule.route[1:idx],[waitingActivityNew],schedule.route[(idx+1):end])
        schedule.numberOfWalking = vcat(schedule.numberOfWalking[1:idx],[schedule.numberOfWalking[idx]],schedule.numberOfWalking[(idx+1):end])

        # Update current schedule
        currentSchedule.route = schedule.route[(idx+2):end]

        # Update active time window
        currentSchedule.activeTimeWindow.startTime = currentTime
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRouteOnline(scenario.time,currentSchedule.route,currentState.visitedRoute,scenario.serviceTimes)
        
            
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
        currentSchedule.numberOfWalking = schedule.numberOfWalking[(idx+2):end]

        currentState.solution.totalDistance += currentSchedule.totalDistance
        currentState.solution.totalRideTime += currentSchedule.totalTime
        currentState.solution.totalCost += currentSchedule.totalCost
        currentState.solution.totalIdleTime += currentSchedule.totalIdleTime

        return idx+1, currentTime
    else
        # Retrieve empty schedule to update it
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        # Update route 
        currentSchedule.route = schedule.route[idx+1:end]

        # Update active time window
        currentSchedule.activeTimeWindow.startTime = schedule.route[idx+1].startOfServiceTime 
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime

        # Update current state pre
        currentState.solution.totalDistance -= currentSchedule.totalDistance
        currentState.solution.totalRideTime -= currentSchedule.totalTime
        currentState.solution.totalCost -= currentSchedule.totalCost
        currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime

        # Update KPIs
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRouteOnline(scenario.time,currentSchedule.route,currentState.visitedRoute,scenario.serviceTimes)
        
            
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
        currentSchedule.numberOfWalking = schedule.numberOfWalking[idx+1:end]

        # Update current state pro
        currentState.solution.totalDistance += currentSchedule.totalDistance
        currentState.solution.totalRideTime += currentSchedule.totalTime
        currentState.solution.totalCost += currentSchedule.totalCost
        currentState.solution.totalIdleTime += currentSchedule.totalIdleTime

        return idx, currentSchedule.activeTimeWindow.startTime
    end

end


# ------
# Function to update current state if vehicle is still available but all customers are still being serviced
# ------
function updateCurrentScheduleAvailableKeepEntireRoute(schedule::VehicleSchedule,currentState::State,vehicle::Int,currentTime::Int,scenario::Scenario)

    # If the activity we are currently servicing is a waiting activity we need to split it into 2 waiting activities 
    if schedule.route[1].activity.activityType == WAITING
        currentSchedule = currentState.solution.vehicleSchedules[vehicle]

        currentState.solution.totalDistance -= currentSchedule.totalDistance
        currentState.solution.totalRideTime -= currentSchedule.totalTime
        currentState.solution.totalCost -= currentSchedule.totalCost
        currentState.solution.totalIdleTime -= currentSchedule.totalIdleTime

        waitingActivity = schedule.route[1]

        # Create new waiting activity 
        waitingActivityNew = ActivityAssignment(Activity(waitingActivity.activity.id,-1,WAITING, waitingActivity.activity.location,TimeWindow(waitingActivity.startOfServiceTime,currentTime)), schedule.vehicle,waitingActivity.startOfServiceTime,currentTime)

        # Update existing waiting activity 
        waitingActivity.startOfServiceTime = currentTime
        waitingActivity.activity.timeWindow.startTime = currentTime

        # Update route of schedule 
        schedule.route = vcat([waitingActivityNew],schedule.route)

        # Update current schedule
        currentSchedule.route = schedule.route[2:end]

        # Update active time window
        currentSchedule.activeTimeWindow.startTime = currentTime
        currentSchedule.activeTimeWindow.endTime = currentSchedule.route[end].endOfServiceTime
        currentSchedule.totalDistance = getTotalDistanceRoute(currentSchedule.route,scenario)
        currentSchedule.totalTime = getTotalTimeRoute(currentSchedule)
        currentSchedule.totalCost = getTotalCostRouteOnline(scenario.time,currentSchedule.route,currentState.visitedRoute,scenario.serviceTimes)
        
            
        currentSchedule.totalIdleTime = getTotalIdleTimeRoute(currentSchedule.route)    
        currentSchedule.numberOfWalking = schedule.numberOfWalking

        currentState.solution.totalDistance += currentSchedule.totalDistance
        currentState.solution.totalRideTime += currentSchedule.totalTime
        currentState.solution.totalCost += currentSchedule.totalCost
        currentState.solution.totalIdleTime += currentSchedule.totalIdleTime

        return 1, currentTime
    else
        # Update current schedule 
        currentState.solution.vehicleSchedules[vehicle] = schedule

        return 0, 0
    end
    
end


# ------
# Function to update waiting activity in route 
# ------
# Assuming waiting activity is the last activity in the route before depot 
function updateLastWaitingActivityInRoute!(time::Array{Int,2},distance::Array{Float64,2},currentSolution::Solution,currentSchedule::VehicleSchedule,waitingIdx::Int,waitingLocationId::Int,location::Location,activityBeforeWaiting::ActivityAssignment)
    
    waitingActivity = currentSchedule.route[waitingIdx]
    depotActivity = currentSchedule.route[end]
    endOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.endTime

    # Update KPIs 
    currentSolution.totalIdleTime -= currentSchedule.totalIdleTime
    currentSolution.totalRideTime -= currentSchedule.totalTime
    currentSolution.totalDistance -= currentSchedule.totalDistance

    currentSchedule.totalIdleTime -= waitingActivity.endOfServiceTime - waitingActivity.startOfServiceTime
    if length(currentSchedule.route) == 2
        currentSchedule.totalDistance -= distance[waitingActivity.activity.id,depotActivity.activity.id]
    else
        currentSchedule.totalDistance -= (distance[activityBeforeWaiting.activity.id,waitingActivity.activity.id] + distance[waitingActivity.activity.id,depotActivity.activity.id] )
    end
    
    waitingActivity.activity.location = location
    waitingActivity.activity.id = waitingLocationId

    # Find arrival at waiting node 
    timePreviousNode = time[activityBeforeWaiting.activity.id,waitingLocationId]
    timeDepot = time[waitingLocationId,depotActivity.activity.id]
    arrivalAtWaiting = activityBeforeWaiting.endOfServiceTime + timePreviousNode

    waitingActivity.startOfServiceTime = arrivalAtWaiting
    waitingActivity.endOfServiceTime = currentSchedule.vehicle.availableTimeWindow.endTime - timeDepot
    waitingActivity.activity.timeWindow = TimeWindow(waitingActivity.startOfServiceTime,waitingActivity.endOfServiceTime)

    # Update depot 
    depotActivity.startOfServiceTime = endOfAvailableTimeWindow
    depotActivity.endOfServiceTime = endOfAvailableTimeWindow

    # Update active time window
    currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow

    # Update KPIs
    currentSchedule.totalIdleTime += waitingActivity.endOfServiceTime - arrivalAtWaiting
    if length(currentSchedule.route) == 2
        currentSchedule.activeTimeWindow.startTime = arrivalAtWaiting
        currentSchedule.totalDistance += distance[waitingLocationId,depotActivity.activity.id]
    else
        currentSchedule.totalDistance += (distance[activityBeforeWaiting.activity.id,waitingLocationId] + distance[waitingLocationId,depotActivity.activity.id] )
    end
    currentSchedule.totalTime = endOfAvailableTimeWindow - currentSchedule.route[1].startOfServiceTime

    # Update current state pro
    currentSolution.totalDistance += currentSchedule.totalDistance
    currentSolution.totalRideTime += currentSchedule.totalTime
    currentSolution.totalIdleTime += currentSchedule.totalIdleTime

    return arrivalAtWaiting
end

function relocateWaitingActivityBeforeDepot!(time::Array{Int,2},distance::Array{Float64,2},nRequests::Int,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},vehicleBalance::Array{Int,3},
    activeVehiclesPerCell::Array{Int,3},probabilityGrid::Array{Float64,2},realisedDemand::Array{Int,3},predictedDemand::Array{Float64,3},
    currentSolution::Solution,currentSchedule::VehicleSchedule,finalSolution::Solution,nTimePeriods::Int,periodLength::Int,vehicleDemand::Array{Int,3},
    displayPlots::Bool,scenarioName::String,currentTime::Int,relocateWithDemand::Bool)
    
    vehicle = currentSchedule.vehicle
    currentRouteLength = length(currentSchedule.route)
    waitingIdx = currentRouteLength - 1
    finalSchedule = finalSolution.vehicleSchedules[vehicle.id]
    previousWaitingLocation = currentSchedule.route[waitingIdx].activity.location
    previousWaitingLocationId = currentSchedule.route[waitingIdx].activity.id

    # Determine relocation time 
    relocationTime = currentSchedule.route[waitingIdx].startOfServiceTime

    # Determine period 
    period = min(Int(ceil(relocationTime / periodLength)), nTimePeriods)

    # If we relocate using demand 
     if relocateWithDemand && all(vehicleBalance[period,:,:] .>= 0)
        previousGridCell = determineGridCell(previousWaitingLocation,grid)

        println("==> No relocation needed for vehicle ",vehicle.id," in period ",period, " minimum: ",minimum(vehicleBalance[period,:,:]), " maximum predicted demand: ", maximum(predictedDemand[period,:,:]))
        return
    end

    # Find current grid cell of waiting activity
    previousGridCell = determineGridCell(previousWaitingLocation,grid)
    if activeVehiclesPerCell[period,previousGridCell[1],previousGridCell[2]] <= 0
        println("No active vehicle in cell: ", previousGridCell, " for vehicle ",vehicle.id," in period ",period)
        throw(ArgumentError("No active vehicle in cell: $(previousGridCell) for vehicle $(vehicle.id) in period $(period)"))
    end

    # Determine previous activity 
    if currentRouteLength == 2 && currentSchedule.route[1].activity.activityType != DEPOT # If only waiting and depot left in current schedule 
        activityBeforeWaiting = finalSchedule.route[end]
    # elseif currentRouteLength == 2 && currentSchedule.route[1].activity.activityType == DEPOT
    #     activityBeforeWaiting = currentSchedule.route[waitingIdx]
    else
        activityBeforeWaiting = currentSchedule.route[waitingIdx-1]
    end

    # Find waiting location
    if relocateWithDemand
        waitingLocationId,waitingLocation,gridCell = determineWaitingLocation(time,depotLocations,grid,nRequests,vehicleBalance,period,previousWaitingLocationId)
    else
        activityBeforeWaitingId = activityBeforeWaiting.activity.id
        endOfServiceActivityBeforeWaiting = activityBeforeWaiting.endOfServiceTime

        isRouteEmpty = isVehicleScheduleEmpty(currentSchedule)
        waitingLocationId,waitingLocation,gridCell,score = determineWaitingLocation2(time,nRequests,depotLocations,grid,probabilityGrid,activeVehiclesPerCell,period,previousGridCell,previousWaitingLocationId,activityBeforeWaitingId,isRouteEmpty,endOfServiceActivityBeforeWaiting,periodLength,nTimePeriods)
    end
    println("Waiting location: ",waitingLocationId, ", period: ",period, ", relocation time: ",relocationTime) 

    if waitingLocationId == previousWaitingLocationId
        println("Did not relocate vehicle ",vehicle.id," as same previous")
        return
    end
 
    # Is there time to relocate vehicle 
    if activityBeforeWaiting.endOfServiceTime + time[activityBeforeWaiting.activity.id,waitingLocationId] + time[waitingLocationId,vehicle.depotId] <= vehicle.availableTimeWindow.endTime

        # Update waiting activity 
        splitTime = updateLastWaitingActivityInRoute!(time,distance,currentSolution,currentSchedule,waitingIdx,waitingLocationId,waitingLocation,activityBeforeWaiting) 
        
        # Determine previous grid cell 
        previousGridCell = determineGridCell(previousWaitingLocation,grid)

        # Plot relocation 
        if displayPlots
            if relocateWithDemand 
                p = plotRelocation(predictedDemand,activeVehiclesPerCell,realisedDemand,vehicleBalance,gridCell,previousGridCell,period,periodLength,vehicle,vehicleDemand)
                display(p)
                savefig(p,"tests/WaitingPlots/"*scenarioName*"/true_true/CurrentSolutionTime"*string(currentTime)*"_vehicle"*string(vehicle.id)*".png")
            else
                p = plotRelocation2(probabilityGrid,score,activeVehiclesPerCell,gridCell,previousGridCell,period,periodLength,vehicle.id)
                display(p)
                savefig(p,"tests/WaitingPlots/"*scenarioName*"/true_false/CurrentSolutionTime"*string(currentTime)*"RELOCATION.png")
            end
        end

        # Update vehicle balance
        waitingActivityStartTime = currentSchedule.route[waitingIdx].startOfServiceTime
        waitingActivityEndTime = currentSchedule.route[waitingIdx].endOfServiceTime
        waitingStartPeriod = min(Int(ceil(waitingActivityStartTime / periodLength)), nTimePeriods)
        waitingEndPeriod = min(Int(ceil(waitingActivityEndTime / periodLength)), nTimePeriods)

        if any(activeVehiclesPerCell[waitingStartPeriod:waitingEndPeriod,:,:] .< 0)
            println("Warning: Negative vehicle balance after relocation of vehicle ",vehicle.id," in period ",period)
            println("Previous grid cell: ",previousGridCell," New grid cell: ",gridCell)
        end

        # Update final solution 
        if currentRouteLength == 2 && length(finalSchedule.route) > 0 # If previous activity is in final solution 
            # Update distance 
            oldDistance = distance[activityBeforeWaiting.activity.id,previousWaitingLocationId]
            newDistance = distance[activityBeforeWaiting.activity.id,waitingLocationId]
            finalSchedule.totalDistance -= oldDistance
            finalSchedule.totalDistance += newDistance
            finalSolution.totalDistance -= oldDistance
            finalSolution.totalDistance += newDistance

            # Update total time 
            oldTime = finalSchedule.totalTime
            newTime = splitTime - finalSchedule.route[1].startOfServiceTime
            finalSchedule.totalTime  = newTime 
            finalSolution.totalRideTime -= oldTime
            finalSolution.totalRideTime += newTime
        end

        println("Relocating vehicle ",vehicle.id," to waiting location ",waitingLocationId," from location ",previousWaitingLocationId, " in period ",period)

        return 
    end
    println("Did not relocate vehicle ",vehicle.id," as no time")
end

#------
# Function to relocate vehicles
#------
function relocateVehicles!(time::Array{Int,2},distance::Array{Float64,2},nRequests::Int,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location}, predictedDemand::Array{Float64,3},probabilityGrid::Array{Float64,2},
                          currentSolution::Solution, currentVehicleSchedulesToRelocate::Vector{VehicleSchedule},finalSolution::Solution,currentTime::Int,nTimePeriods::Int,periodLength::Int,
                          displayPlots::Bool,scenarioName::String,relocateWithDemand::Bool,gamma::Float64)
   
    # Retrieve vehicle schedules in solution 
    currentVehicleSchedules = currentVehicleSchedulesToRelocate

    # Sort vehicle schedules by start time of end waiting activity 
    waitingTimes = []
    for currentSchedule in currentVehicleSchedules
        if  length(currentSchedule.route) == 1 || currentSchedule.vehicle.availableTimeWindow.endTime <= currentTime
            push!(waitingTimes,typemax(Int))
        elseif currentSchedule.route[end-1].activity.activityType == WAITING
            push!(waitingTimes,currentSchedule.route[end-1].startOfServiceTime)
        else
            push!(waitingTimes,currentSchedule.route[end].startOfServiceTime)
        end
    end
    sortedIdx = sortperm(waitingTimes)

    # Go through current schedules in order and relocate vehicles 
    for currentSchedule in currentVehicleSchedules[sortedIdx]
        route = currentSchedule.route
        routeLength  = length(route)
        vehicle = currentSchedule.vehicle
        endOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.endTime

        println("\n==> vehicle: ",vehicle.id)

        # Check if vehicle should be relocated 
        # Either the route is completed or the route is "full" and there is no room for waiting activity or the route is empty
        if  routeLength == 1 || endOfAvailableTimeWindow <= currentTime || # Completed route 
            (routeLength > 2 && (route[end-1].activity.activityType != WAITING) && route[end].startOfServiceTime == endOfAvailableTimeWindow) # Full route 
            # || (routeLength == 2 && route[1].activity.activityType == DEPOT && route[end].activity.activityType == DEPOT) # Empty route 
            continue
        end

        # Add waiting activity at end of route if not already there
        if (routeLength == 2 && route[1].activity.activityType == DEPOT && route[end].activity.activityType == DEPOT) # Empty route 
            println("Adding waiting activity at end of route for empty vehicle ",vehicle.id)

            endOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.endTime
            startOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.startTime
        
            # Create waiting activity at depot activity 
            waitingActivity = ActivityAssignment(Activity(vehicle.depotId,-1,WAITING, vehicle.depotLocation,TimeWindow(startOfAvailableTimeWindow,endOfAvailableTimeWindow)), vehicle,startOfAvailableTimeWindow,endOfAvailableTimeWindow)
            currentSchedule.route = [route[1],waitingActivity,route[end]]

            # Update route with waiting activity 
            currentSchedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            currentSchedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
            currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            currentSchedule.totalTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            currentSchedule.totalIdleTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            currentSchedule.numberOfWalking = vcat(currentSchedule.numberOfWalking,[0])

            currentSolution.totalRideTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            currentSolution.totalIdleTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow

        elseif route[end-1].activity.activityType != WAITING
            println("Adding waiting activity at end of route for vehicle ",vehicle.id)

            arrivalAtDepot = currentSchedule.route[end].startOfServiceTime
            endOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.endTime
        
            # Create waiting activity at depot activity 
            waitingActivity = ActivityAssignment(Activity(vehicle.depotId,-1,WAITING, vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), vehicle,arrivalAtDepot,endOfAvailableTimeWindow)
        
            # Update route with waiting activity 
            if routeLength > 1
                currentSchedule.route = vcat(route[1:(end-1)],[waitingActivity],[route[end]])
            else
               currentSchedule.route = [waitingActivity,route[end]]
               currentSchedule.activeTimeWindow.startTime = arrivalAtDepot
            end

            currentSchedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            currentSchedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
            currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            currentSchedule.totalTime += endOfAvailableTimeWindow - arrivalAtDepot
            currentSchedule.totalIdleTime += endOfAvailableTimeWindow - arrivalAtDepot
            currentSchedule.numberOfWalking = vcat(currentSchedule.numberOfWalking,[0])

            currentSolution.totalRideTime += endOfAvailableTimeWindow - arrivalAtDepot
            currentSolution.totalIdleTime += endOfAvailableTimeWindow - arrivalAtDepot

        # If we are driving to the waiting location we have to arrive at the waiting location before we can relocate again 
        # The waiting duration has to be longer than the period length
        # We add another waiting activity, where we can relocate the vehicle again
        elseif length(route) == 2 #&& (route[end-1].endOfServiceTime - route[end-1].startOfServiceTime) > periodLength 
            println("Adding extra waiting activity for vehicle ",vehicle.id," at end of route")

            # End current waiting activity after one period length
            waitingActivity = currentSchedule.route[end-1]

            # how long have we been at the waiting node 
            startTimeAtWaitingActivity = 0
            finalRoute = finalSolution.vehicleSchedules[vehicle.id].route
            for i in length(finalRoute):-1:1
                if finalRoute[i].activity.activityType == WAITING && finalRoute[i].activity.id == waitingActivity.activity.id
                    startTimeAtWaitingActivity = finalRoute[i].startOfServiceTime
                else
                    # As soon as we find a different location, stop
                    break
                end
            end

            # We need to stay at least the period length at the waiting activity 
            if startTimeAtWaitingActivity == 0
                extraDuration = periodLength
            else
                extraDuration = periodLength - (waitingActivity.startOfServiceTime - startTimeAtWaitingActivity)
            end 

            # Update the end of service time of the waiting activity
            oldEndOfServiceTime = waitingActivity.endOfServiceTime
            if extraDuration <= 0
               newEndOfServiceTime = waitingActivity.startOfServiceTime # If we have been waiting long enough, we can change location immediately
            else
                newEndOfServiceTime = min(waitingActivity.startOfServiceTime + extraDuration,oldEndOfServiceTime) # continue waiting at activity 
            end
            waitingActivity.endOfServiceTime = newEndOfServiceTime
            waitingActivity.activity.timeWindow.endTime = newEndOfServiceTime

            # Add waiting activity 
            newWaitingActivity = ActivityAssignment(Activity(waitingActivity.activity.id,-1,WAITING, waitingActivity.activity.location,TimeWindow(newEndOfServiceTime,oldEndOfServiceTime)), vehicle,newEndOfServiceTime,oldEndOfServiceTime)

            # Update route 
            currentSchedule.numberOfWalking = vcat(currentSchedule.numberOfWalking,[0])
            currentSchedule.route = vcat(currentSchedule.route[1:(end-1)],[newWaitingActivity],[route[end]])

           # printRouteHorizontal(currentSchedule)   
        end

        # Determine active vehicles per cell 
        # Inefficient but works for now
        if relocateWithDemand
            vehicleBalance,activeVehiclesPerCell,realisedDemand, vehicleDemand = determineVehicleBalancePrCell(grid,gamma,predictedDemand,currentSolution,nTimePeriods,periodLength)
        else
            vehicleBalance = zeros(Int64,0,0,0)
            realisedDemand = zeros(Int64,0,0,0)
            vehicleDemand = zeros(Int64,0,0,0)
            activeVehiclesPerCell = determineActiveVehiclesPrCell(grid,currentSolution,nTimePeriods,periodLength)
        end

        # Relocate waiting activity 
        relocateWaitingActivityBeforeDepot!(time,distance,nRequests,grid,depotLocations,vehicleBalance,activeVehiclesPerCell,probabilityGrid,realisedDemand,predictedDemand,
        currentSolution,currentSchedule,finalSolution,nTimePeriods,periodLength,vehicleDemand,displayPlots,scenarioName,currentTime,relocateWithDemand)
    end 
end



# ------
# Function to update final solution for given vehicle 
# ------
function updateFinalSolution!(scenario::Scenario,finalSolution::Solution,solution::Solution,vehicle::Int,idx::Int,splitTime::Int,visitedRoute::Dict{Int,Dict{String,Int}})
    # Return if no completed route 
    if idx == 0
        return
    end

    # Set start time of time window if necesarry
    if length(finalSolution.vehicleSchedules[vehicle].route) == 0
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow.startTime = solution.vehicleSchedules[vehicle].activeTimeWindow.startTime
    end

    # Retrieve completed route 
    newCompletedRoute =  solution.vehicleSchedules[vehicle].route[1:idx]
    append!(finalSolution.vehicleSchedules[vehicle].route, newCompletedRoute)
   
    # Update active time window 
    finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = splitTime
   
    # Update KPIs of route and solution 
    totalTimeOfNewCompletedRoute = splitTime - newCompletedRoute[1].startOfServiceTime
    newTotalCost =  getTotalCostRouteOnline(scenario.time,newCompletedRoute,visitedRoute,scenario.serviceTimes) 
    totalIdleTime = getTotalIdleTimeRoute(newCompletedRoute)

    endIndex = (idx == length(solution.vehicleSchedules[vehicle].route)) ? idx : idx + 1
    newTotalDistance = getTotalDistanceRoute(solution.vehicleSchedules[vehicle].route[1:endIndex],scenario)

    finalSolution.vehicleSchedules[vehicle].totalTime += totalTimeOfNewCompletedRoute #?
    finalSolution.vehicleSchedules[vehicle].totalDistance += newTotalDistance
    finalSolution.vehicleSchedules[vehicle].totalCost += newTotalCost 
    finalSolution.vehicleSchedules[vehicle].totalIdleTime += totalIdleTime
    append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,solution.vehicleSchedules[vehicle].numberOfWalking[1:idx])

    finalSolution.totalRideTime += totalTimeOfNewCompletedRoute
    finalSolution.totalDistance += newTotalDistance
    finalSolution.totalCost += newTotalCost 
    finalSolution.totalIdleTime += totalIdleTime
end


# ------
# Function to merge current State and final solution in last iteration
# ------
function mergeCurrentStateIntoFinalSolution!(finalSolution::Solution,solution::Solution,scenario::Scenario)
    
    finalSolution.totalRideTime = 0 # Only because no delta calculation
    

    # Loop through all schedules and add to final solution 
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)

        # Set start time of time window if necesarry 
        if length(finalSolution.vehicleSchedules[vehicle].route) == 0
            finalSolution.vehicleSchedules[vehicle].activeTimeWindow.startTime = schedule.activeTimeWindow.startTime
        end

        # Update route 
        finalSolution.vehicleSchedules[vehicle].route = append!(finalSolution.vehicleSchedules[vehicle].route,schedule.route)
     
        # Update active time window 
        finalSolution.vehicleSchedules[vehicle].activeTimeWindow.endTime = schedule.activeTimeWindow.endTime

        # Update KPIs of route
        newDistance = schedule.totalDistance
        newDuration = duration(finalSolution.vehicleSchedules[vehicle].activeTimeWindow)
        newCost = schedule.totalCost 
        newIdleTime = schedule.totalIdleTime

        finalSolution.vehicleSchedules[vehicle].totalDistance += newDistance
        finalSolution.vehicleSchedules[vehicle].totalTime = newDuration 
        finalSolution.vehicleSchedules[vehicle].totalCost += newCost
        finalSolution.vehicleSchedules[vehicle].totalIdleTime += newIdleTime


        finalSolution.vehicleSchedules[vehicle].numberOfWalking = append!(finalSolution.vehicleSchedules[vehicle].numberOfWalking,schedule.numberOfWalking)

        # Update KPIs of solution
        finalSolution.totalRideTime += newDuration
        finalSolution.totalDistance += newDistance
        finalSolution.totalIdleTime += newIdleTime
        finalSolution.totalCost += newCost
    end

    finalSolution.nTaxi += solution.nTaxi
    finalSolution.totalCost += scenario.taxiParameter*finalSolution.nTaxi

    # TODO: inefficient 
    # Calculate KPIs of final solution
    finalSolution.totalRideTime = 0
    finalSolution.totalDistance = 0
    finalSolution.totalIdleTime = 0
    finalSolution.totalCost = 0

    for (vehicle,schedule) in enumerate(finalSolution.vehicleSchedules)
        schedule.totalTime = getTotalTimeRoute(schedule)
        schedule.totalDistance = getTotalDistanceRoute(schedule.route,scenario)
        schedule.totalCost = getTotalCostRoute(scenario,schedule.route)
        schedule.totalIdleTime = getTotalIdleTimeRoute(schedule.route)
        

        finalSolution.totalRideTime += duration(schedule.activeTimeWindow)
        finalSolution.totalDistance += getTotalDistanceRoute(schedule.route,scenario)
        finalSolution.totalIdleTime += getTotalIdleTimeRoute(schedule.route)
        finalSolution.totalCost += getTotalCostRoute(scenario,schedule.route)
    end
    finalSolution.totalCost += scenario.taxiParameter*finalSolution.nTaxi
end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Event,finalSolution::Solution,scenario::Scenario,visitedRoute::Dict{Int,Dict{String,Int}},grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},predictedDemand::Array{Float64,3},probabilityGrid::Array{Float64,2},scenarioName::String;relocateVehicles::Bool=false,nTimePeriods::Int=24,periodLength::Int=60,gamma::Float64=0.5,displayPlots::Bool=false,relocateWithDemand::Bool=false)
    nRequests = length(scenario.requests)
    time = scenario.time
    distance = scenario.distance

    # Initialize current state
    currentState = State(scenario,event.request,visitedRoute,0)
    currentState.solution = copySolution(solution)

    # Initialize 
    idx = -1
    splitTime = -1

    # Get current time
    currentTime = event.callTime

    # Update vehicle schedule
    for (vehicle,schedule) in enumerate(solution.vehicleSchedules)
      # print("vehicle : ", vehicle )

        # Check if vehicle is not available yet or has not started service yet
        if schedule.vehicle.availableTimeWindow.startTime > currentTime || schedule.route[1].startOfServiceTime > currentTime
            idx, splitTime = updateCurrentScheduleNotAvailableYet(schedule,currentState,vehicle)
           # print(" - not available yet or not started service yet \n")
        # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime <= currentTime || length(schedule.route) == 1|| (schedule.route[end-1].endOfServiceTime < currentTime && schedule.route[end].startOfServiceTime == schedule.vehicle.availableTimeWindow.endTime && schedule.route[1].activity.activityType != DEPOT)
            idx, splitTime = updateCurrentScheduleNotAvailableAnymore!(currentState,schedule,vehicle)
          # print(" - not available anymore \n")
        # Check if vehicle has not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT
         #   idx, splitTime = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
           print(" - no assignments \n")

        # We have completed the last activity and the vehicle is on-route to the depot but still available 
        elseif length(schedule.route) > 1 && schedule.route[end-1].endOfServiceTime < currentTime 
            idx,splitTime = updateCurrentScheduleRouteCompleted!(currentState,schedule,vehicle)
         #  print("- completed route but still available \n")
        else
            # Determine index to split
            didSplit = false
            for (split,assignment) in enumerate(schedule.route[1:(end-1)])
               if assignment.endOfServiceTime <= currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
                    idx, splitTime  = updateCurrentScheduleAtSplit!(scenario,schedule,vehicle,currentState,split,currentTime)
                    didSplit = true
                 #  print(" - still available, split at ",split, ", \n")
                    break
                end
            end

            if didSplit == false
                idx, splitTime = updateCurrentScheduleAvailableKeepEntireRoute(schedule,currentState,vehicle,currentTime,scenario)
              # print(" - still available, keep entire route, \n")
            end
        end

        # Update final solution
        updateFinalSolution!(scenario,finalSolution,solution,vehicle,idx, splitTime,visitedRoute)
    end

    # Update number of taxies 
    finalSolution.nTaxi += solution.nTaxi

    addTaxi = event.id == 0 ? 0 : 1
    currentState.solution.nTaxi = addTaxi # Because of new event
    currentState.solution.totalCost += scenario.taxiParameter*addTaxi
    currentState.totalNTaxi = finalSolution.nTaxi
    currentState.solution.nTaxiExpected = 0

    # Relocate vehicles if relocation event 
    # Relocate vehicles when they have serviced all customers in route 
    if relocateVehicles && event.id == 0
        relocateVehicles!(time,distance,nRequests,grid,depotLocations,predictedDemand,probabilityGrid,
        currentState.solution,currentState.solution.vehicleSchedules,finalSolution,currentTime,nTimePeriods,periodLength,displayPlots,scenarioName,relocateWithDemand,gamma)
    end

    return currentState, finalSolution
end



# ------
# Function to add waiting activities to empty route 
# ------
function addWaitingActivitiesAtEndOfEmptyRoute(solution::Solution)
    for schedule in solution.vehicleSchedules
        if length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            # Create waiting activity at depot activity 
            endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime
            startOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.startTime
        
            # Create waiting activity at depot activity 
            waitingActivity = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(startOfAvailableTimeWindow,endOfAvailableTimeWindow)), schedule.vehicle,startOfAvailableTimeWindow,endOfAvailableTimeWindow)
            schedule.route = [schedule.route[1],waitingActivity,schedule.route[end]]

            # Update route with waiting activity 
            schedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            schedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
            schedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            schedule.totalTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            schedule.totalIdleTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            schedule.numberOfWalking = vcat(schedule.numberOfWalking,[0])

            solution.totalRideTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            solution.totalIdleTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
        end
    end
end

# ------
# Function to add waiting activities back into routes after ALNS 
# ------
function addWaitingActivitiesAtEndOfRouteAfterALNS(solution::Solution,scenario::Scenario,relocateVehicles::Bool=false)
    nRequests = length(scenario.requests)

    # Keep track of schedules where waiting activity has to be relocated
    schedulesToRelocate = Vector{VehicleSchedule}()


    # Go through all vehicle schedules and add waiting activity if needed
    for schedule in solution.vehicleSchedules
        if length(schedule.route) == 1
            continue
        end

        # Empty route with waiting activity 
        if length(schedule.route) == 3 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            # Extend waiting activity at depot at end of route
            startOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.startTime
            endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime
            
            newStartOfWaiting = startOfAvailableTimeWindow + scenario.time[schedule.route[1].activity.id,schedule.route[end-1].activity.id]
            newEndOfWaiting = endOfAvailableTimeWindow - scenario.time[schedule.route[end-1].activity.id,schedule.route[end].activity.id]

            # Update route 
            solution.totalIdleTime -= schedule.totalIdleTime
            solution.totalRideTime -= schedule.totalTime

            schedule.route[end-1].startOfServiceTime = newStartOfWaiting
            schedule.route[end-1].endOfServiceTime = newEndOfWaiting
            schedule.route[end-1].activity.timeWindow.startTime = newStartOfWaiting
            schedule.route[end-1].activity.timeWindow.endTime = newEndOfWaiting
            schedule.route[1].startOfServiceTime = startOfAvailableTimeWindow
            schedule.route[1].endOfServiceTime = startOfAvailableTimeWindow
            schedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            schedule.route[end].endOfServiceTime = endOfAvailableTimeWindow

            schedule.activeTimeWindow.startTime = startOfAvailableTimeWindow
            schedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            schedule.totalIdleTime = newEndOfWaiting - newStartOfWaiting
            schedule.totalTime = getTotalTimeRoute(schedule)

            solution.totalIdleTime += schedule.totalIdleTime
            solution.totalRideTime += schedule.totalTime
        # Empty route with no waiting activity 
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            # Create waiting activity at depot activity 
            endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime
            startOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.startTime

            solution.totalIdleTime -= schedule.totalIdleTime
            solution.totalRideTime -= schedule.totalTime
        
            # Create waiting activity at depot activity 
            waitingActivity = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(startOfAvailableTimeWindow,endOfAvailableTimeWindow)), schedule.vehicle,startOfAvailableTimeWindow,endOfAvailableTimeWindow)
            schedule.route = [schedule.route[1],waitingActivity,schedule.route[end]]

            # Update route with waiting activity 
            schedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            schedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
            schedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            schedule.totalTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            schedule.totalIdleTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            schedule.numberOfWalking = vcat(schedule.numberOfWalking,[0])

            solution.totalRideTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow
            solution.totalIdleTime += endOfAvailableTimeWindow - startOfAvailableTimeWindow

        # Route with end-of-route waiting activity but it has been shortened 
        elseif schedule.route[end-1].activity.activityType == WAITING && schedule.route[end].startOfServiceTime != schedule.vehicle.availableTimeWindow.endTime
            # Extend waiting activity at depot at end of route
            endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime
            newEndOfWaiting = endOfAvailableTimeWindow - scenario.time[schedule.route[end-1].activity.id,schedule.route[end].activity.id]
            oldEndOfWaiting = schedule.route[end-1].endOfServiceTime

            # Update route 
            solution.totalIdleTime -= schedule.totalIdleTime
            solution.totalRideTime -= schedule.totalTime

            schedule.route[end-1].endOfServiceTime = newEndOfWaiting
            schedule.route[end-1].activity.timeWindow.endTime = newEndOfWaiting
            schedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            schedule.route[end].endOfServiceTime = endOfAvailableTimeWindow

            schedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            schedule.totalIdleTime += newEndOfWaiting - oldEndOfWaiting
            schedule.totalTime = getTotalTimeRoute(schedule)

            solution.totalIdleTime += schedule.totalIdleTime
            solution.totalRideTime += schedule.totalTime

        # If relocation and no end of route waiting activity, then relocate vehicle
        elseif relocateVehicles && schedule.route[end-1].activity.activityType != WAITING
            push!(schedulesToRelocate,schedule)

        # If no relocation and no end of route waiting activity, then add waiting activity
        elseif schedule.route[end-1].activity.activityType != WAITING
            # Add waiting activity at depot at end of route 
            # Retrieve schedule and update it 

            arrivalAtDepot = schedule.route[end].startOfServiceTime
            endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime
        
            # Create waiting activity 
            waitingActivity = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), schedule.vehicle,arrivalAtDepot,endOfAvailableTimeWindow)
        
            # Update route 
            solution.totalIdleTime -= schedule.totalIdleTime
            solution.totalRideTime -= schedule.totalTime

            schedule.route = vcat(schedule.route[1:(end-1)],[waitingActivity],[schedule.route[end]])
            schedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
            schedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
            schedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
            schedule.totalIdleTime += endOfAvailableTimeWindow - arrivalAtDepot
            schedule.totalTime = getTotalTimeRoute(schedule)
            schedule.numberOfWalking = vcat(schedule.numberOfWalking,[0])

            solution.totalIdleTime += schedule.totalIdleTime
            solution.totalRideTime += schedule.totalTime
        end
    end

    return schedulesToRelocate
end



# ------
# Function to determine drive time to closest idle vehicle
# ------
function driveTimeToClosestIdleVehicle(currentState::State,event::Event,scenario::Scenario)
    callTime = event.callTime
    closestDriveTime = typemax(Int)
    closestActivityId = -1
    cloestVehicle = -1
    closestVehicleOverlap = -1
    numberOfVehiclesOverlap = 0

    for schedule in currentState.solution.vehicleSchedules
        # vehicle has to be idle in pick-up time window 
        if length(schedule.route) == 1 || schedule.vehicle.availableTimeWindow.startTime > callTime || schedule.vehicle.availableTimeWindow.endTime < callTime
            continue
        end

        # Check if vehicle is idle in pick-up time window 
        lastActivity = schedule.route[end - 1]
        if lastActivity.activity.activityType == WAITING && lastActivity.startOfServiceTime <= event.request.pickUpActivity.timeWindow.endTime && event.request.pickUpActivity.timeWindow.startTime <= lastActivity.endOfServiceTime
            # Get drive time to pick-up location 
            driveTime = scenario.time[schedule.route[end-1].activity.id,event.request.pickUpActivity.id]

            numberOfVehiclesOverlap += 1

            if driveTime < closestDriveTime
                closestDriveTime = driveTime
                closestActivityId = schedule.route[end-1].activity.id
                cloestVehicle = schedule.vehicle.id

                vehicleIdleStart = lastActivity.startOfServiceTime
                vehicleIdleEnd = lastActivity.endOfServiceTime
                pickupStart = event.request.pickUpActivity.timeWindow.startTime
                pickupEnd = event.request.pickUpActivity.timeWindow.endTime

                closestVehicleOverlap = max(0, min(vehicleIdleEnd, pickupEnd) - max(vehicleIdleStart, pickupStart))
            end

        # Check if vehicle has not left depot yet 
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            # Get drive time to pick-up location 
            driveTime = scenario.time[schedule.route[1].activity.id,event.request.pickUpActivity.id]
            numberOfVehiclesOverlap += 1

            if driveTime < closestDriveTime
                closestDriveTime = driveTime
                closestActivityId = schedule.route[1].activity.id
                cloestVehicle = schedule.vehicle.id

                vehicleIdleStart = schedule.route[1].startOfServiceTime
                vehicleIdleEnd = schedule.route[1].endOfServiceTime
                pickupStart = event.request.pickUpActivity.timeWindow.startTime
                pickupEnd = event.request.pickUpActivity.timeWindow.endTime

                closestVehicleOverlap = max(0, min(vehicleIdleEnd, pickupEnd) - max(vehicleIdleStart, pickupStart))
            end
        end
    end

    return closestDriveTime, closestActivityId, cloestVehicle,closestVehicleOverlap, numberOfVehiclesOverlap
end

# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario;alnsParameters::String = "tests/resources/ALNSParameters_offline.json",printResults::Bool = false,saveResults::Bool=false,displayPlots::Bool=false,outPutFileFolder::String="tests/output",saveALNSResults::Bool = false,displayALNSPlots::Bool = false,historicRequestFiles::Vector{String} = Vector{String}(),gamma::Float64=0.5,relocateVehicles::Bool=false, anticipation::Bool = false, nExpected::Int=0, gridFile::String="Data/Konsentra/grid.json",nTimePeriods::Int=24,periodLength::Int=60,scenarioName::String="",relocateWithDemand::Bool=false,ALNS::Bool=true)
    
    if anticipation == true
        throw("Wrong function call for anticipation!")
    end

    simulateScenario(scenario,"","","","","",alnsParameters,scenarioName;printResults=printResults,saveResults=saveResults,displayPlots=displayPlots,outPutFileFolder=outPutFileFolder,saveALNSResults=saveALNSResults,displayALNSPlots=displayALNSPlots,historicRequestFiles = historicRequestFiles,gamma = gamma,relocateVehicles=relocateVehicles, anticipation=false, nExpected=nExpected, gridFile= gridFile, nTimePeriods = nTimePeriods,periodLength = periodLength,relocateWithDemand = relocateWithDemand,ALNS=ALNS)
   
end

function simulateScenario(scenarioInput::Scenario,requestFile::String,distanceMatrixFile::String,timeMatrixFile::String,vehiclesFile::String,parametersFile::String,alnsParameters::String,scenarioName::String;printResults::Bool = false,saveResults::Bool=false,displayPlots::Bool=false,outPutFileFolder::String="tests/output",saveALNSResults::Bool = false,displayALNSPlots::Bool = false,historicRequestFiles::Vector{String} = Vector{String}(),gamma::Float64=0.5,relocateVehicles::Bool=false, anticipation::Bool = false, nExpected::Int=0, gridFile::String="Data/Konsentra/grid.json", ALNS::Bool=true, nTimePeriods::Int=24,periodLength::Int=60,testALNS::Bool=false, keepExpectedRequests::Bool=false,measureSlack::Bool=false,relocateWithDemand::Bool=false,useAnticipationOnlineRequests::Bool=false,splitRequestBank::Bool=true)

    if !isdir("tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand))
        mkpath("tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand))
    end

    # Copy scenario so that we don't modify actual scenario
    scenario = copyScenario(scenarioInput)
    nRequests = length(scenario.requests)

    # Count number of requests that have pick-up time window that overlaps with idle vehicle 
    numberOfRequestsOverlapIdleVehicle = 0 
    # Sum durations to nearest idle vehicle 
    driveTimeToNearestIdleVehicle = 0 
    driveTimeToNearestIdleVehicleVector = Vector{Int64}()
    requestIds = Vector{Int64}()
    isInsertedIntoClosestVehicle = Vector{Bool}()
    closestVehicleOverlapVector = Vector{Int64}()
    numberOfVehiclesOverlapVector = Vector{Int64}()

    # Retrieve info 
    if relocateVehicles
        grid = scenario.grid
        depotLocations = scenario.depotLocations
    else
        grid = Grid()
        depotLocations = Dict{Tuple{Int,Int},Location}()
    end
    

    # Generate predicted demand
    if relocateVehicles
        predictedDemand = generatePredictedDemand(grid, historicRequestFiles,nTimePeriods,periodLength)
        probabilityGrid = getProbabilityGrid(scenario,historicRequestFiles)
    else 
        predictedDemand = zeros(Float64,0,0,0)
        probabilityGrid = zeros(Float64,0,0)
    end

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    # Initialize current state 
    initialVehicleSchedules = [VehicleSchedule(vehicle,true) for vehicle in scenario.vehicles] 
    finalSolution = Solution(initialVehicleSchedules, 0.0, 0, 0, 0.0, 0) 
    currentState = State(scenario,Request(),0)
    nRequests = length(scenario.requests)

    if anticipation == false
        solution, requestBank, ALNSIterations = offlineSolution(scenario,repairMethods,destroyMethods,parametersFile,alnsParameters,scenarioName,saveALNSResults=saveALNSResults,displayALNSPlots=displayALNSPlots,splitRequestBank=splitRequestBank)
        nNotServicedExpectedRequests = 0 # Dummy
    elseif anticipation == true && keepExpectedRequests == false
        solution, requestBank, resultsAnticipation,_,_,_,_,ALNSIterations = offlineSolutionWithAnticipation(repairMethods,destroyMethods,requestFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,nExpected,gridFile,length(scenario.offlineRequests),displayPlots=displayPlots,splitRequestBank=splitRequestBank)
        updateIds!(solution,length(scenario.requests),nExpected)
        requestBank = requestBank[requestBank .<= scenario.nFixed]

        if saveResults == true
            if !isdir(outPutFileFolder)
                mkpath(outPutFileFolder)
            end
            fileName = outPutFileFolder*"/Anticipation_KPI_"*string(scenario.name)*".json"
            file = open(fileName, "w") 
            write(file, JSON.json(resultsAnticipation))
            close(file)
        end
        nNotServicedExpectedRequests = 0 # Dummy
    else
        solution, requestBank, resultsAnticipation, scenario,_,_,_,ALNSIterations = offlineSolutionWithAnticipation(repairMethods,destroyMethods,requestFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,nExpected,gridFile,length(scenario.offlineRequests),displayPlots=displayPlots,keepExpectedRequests=keepExpectedRequests,useAnticipationOnlineRequests=useAnticipationOnlineRequests,splitRequestBank=splitRequestBank)
        nRequestBankTemp = length(requestBank)
        expectedRequestBank = requestBank[requestBank .> scenario.nFixed]
        whatHappensToExpected = zeros(Int,6)
        requestBank = requestBank[requestBank .<= scenario.nFixed]
        nNotServicedExpectedRequests = nRequestBankTemp - length(requestBank) 
        solution.nTaxiExpected = 0
        solution.totalCost -= nNotServicedExpectedRequests*scenario.taxiParameterExpected

        # Save slack before and after ALNS on solution  
        if measureSlack
            testSol = copySolution(solution)
            testSol.nTaxi = 0
            testSol.nTaxiExpected = 0
            testSolALNS, _,_,_, _,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=testSol,alreadyRejected=solution.nTaxi)

            slackBeforeALNS = measureSlackInSolution(solution,finalSolution,scenario,scenario.nFixed)
            slackAfterALNS = measureSlackInSolution(testSolALNS,finalSolution,scenario,scenario.nFixed)
        else
            slackBeforeALNS = 0
            slackAfterALNS = 0
        end

        if saveResults == true
            if !isdir(outPutFileFolder)
                mkpath(outPutFileFolder)
            end
       
            # Create a Dict with all columns from the DataFrame
            dict_data = Dict{String, Any}(col => resultsAnticipation[!, col] for col in names(resultsAnticipation))
            
            # Add your scalar slack values
            dict_data["slackBeforeALNS"] = slackBeforeALNS
            dict_data["slackAfterALNS"] = slackAfterALNS
            
            fileName = outPutFileFolder*"/Anticipation_KPI_"*string(scenario.name)*".json"
            file = open(fileName, "w") 
            write(file, JSON.json(dict_data))
            close(file)
        end
    end

    nNotServicedExpectedRequestsOffline = copy(nNotServicedExpectedRequests)
    requestBankOffline = deepcopy(requestBank)
    initialSolution = copySolution(solution)

    # Update time windows 
    updateTimeWindowsOnline!(solution,scenario)

    # Add waiting activity to empty routes 
    addWaitingActivitiesAtEndOfEmptyRoute(solution)

    # Print routes
    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Intitial after ALNS")
        println("----------------")
        printSolution(solution,printRouteHorizontal)
    end
    if displayPlots
        p1 = createGantChartOfSolutionOnline(solution,"Initial Solution after ALNS",nRequests,nFixed=scenario.nFixed)
        p2 = plotRoutes(solution,scenario,requestBank,"Initial Solution after ALNS")
        display(p1)
        display(p2)

        if !isdir("tests/WaitingPlots/"*scenarioName)
            mkpath("tests/WaitingPlots/"*scenarioName)
        end

        savefig(p1,"tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/InitialSolutionAfterALNS.png")
        savefig(p2,"tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/InitialSolutionAfterALNSRoutes.png")
    end

    # Initialize visited routes 
    visitedRoute = Dict{Int,Dict{String,Int}}()

    # Create events 
    onlineEvents = [Event(r.id,r.callTime,r) for r in scenario.onlineRequests]
    onlineCallTimes = [r.callTime for r in scenario.onlineRequests]
    periodicRelocationEvent = []
    if relocateVehicles
        for t in scenario.planningPeriod.startTime:periodLength:scenario.planningPeriod.endTime
            if !(t in onlineCallTimes)
                push!(periodicRelocationEvent,Event(0,t,Request(t)))
            end
        end
    end
    events = vcat(onlineEvents,periodicRelocationEvent)
    events = sort!(events, by = x -> x.callTime)

    # Get solution for online problem
    averageResponseTime = 0
    startSimulation = time()
    eventsInsertedByALNS = 0
    totalEvents = length(events)
    nOnline = 0
    averageNotServicedExpectedRequests = zeros(Float64,totalEvents)
    averageNotServicedExpectedRequestsRelevant = zeros(Float64,totalEvents)


    for (itr,event) in enumerate(events)



        startTimeEvent = time()
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Event: id: ", itr, ", time: ", event.callTime, " request id: ", event.id, " pick up time: ",event.request.pickUpActivity.timeWindow)
        println("----------------")

        # Determine current state
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario,visitedRoute,grid,depotLocations,predictedDemand,probabilityGrid,scenarioName,relocateVehicles=relocateVehicles,gamma=gamma,displayPlots=displayPlots,nTimePeriods=nTimePeriods,periodLength=periodLength,relocateWithDemand=relocateWithDemand)
        oldSolution = copySolution(currentState.solution)

        if printResults
            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Current solution: ")
            println("----------------")
            printSolution(currentState.solution,printRouteHorizontal)

            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Final solution: ")
            println("----------------")
            printSolution(finalSolution,printRouteHorizontal)
        end
     
        
        # CHeck feasibility 
        if !keepExpectedRequests
            feasible, msg = checkSolutionFeasibilityOnline(scenario,currentState,checkOnline=true)
        else
            feasible, msg = checkSolutionFeasibilityOnline(scenario,currentState,checkOnline=true,nExpected=nNotServicedExpectedRequests)
        end

        if !feasible
            println("INFEASIBLE SOLUTION IN ITERATION:", itr)
            println("nOnline: ", nOnline,"/",length(scenario.onlineRequests))
            throw(msg)
            return currentState, requestBank
        end

        # Find drive time to closest idle vehicle for event 
        closestVehicle = -1
        if event.id != 0 
            closestDriveTime, closestActivityId, closestVehicle,closestVehicleOverlap,numberOfVehiclesOverlap = driveTimeToClosestIdleVehicle(currentState,event,scenario)

            if closestActivityId != -1 
                push!(driveTimeToNearestIdleVehicleVector,closestDriveTime)
                push!(requestIds,event.id)
                push!(closestVehicleOverlapVector,closestVehicleOverlap)
                push!(numberOfVehiclesOverlapVector,numberOfVehiclesOverlap)
                numberOfRequestsOverlapIdleVehicle += 1 
                driveTimeToNearestIdleVehicle += closestDriveTime
            end
        end

        # Get solution for online problem
        if event.id != 0
            nOnline += 1

            solution, requestBank,insertedByALNS = onlineAlgorithm(currentState, requestBank, scenario, destroyMethods, repairMethods, ALNS = ALNS, nNotServicedExpectedRequests=nNotServicedExpectedRequests,splitRequestBank=splitRequestBank) 
            
            if keepExpectedRequests
                # Check if event has been changed with its matching request
                matchingId = event.request.id - length(scenario.offlineRequests) + length(scenario.requests)
                if event.request.id in requestBank && matchingId in expectedRequestBank
                    whatHappensToExpected[1] += 1
                elseif event.request.id in requestBank && !(matchingId in expectedRequestBank)
                    whatHappensToExpected[2] += 1
                elseif !(event.request.id in requestBank) && !(matchingId in expectedRequestBank) && !(matchingId in requestBank)
                    whatHappensToExpected[3] += 1
                elseif !(event.request.id in requestBank) && (matchingId in requestBank)
                    whatHappensToExpected[4] += 1
                elseif !(event.request.id in requestBank) && (matchingId in expectedRequestBank)
                    whatHappensToExpected[5] += 1
                else
                    whatHappensToExpected[6] += 1
                end

                append!(expectedRequestBank, requestBank[requestBank .> scenario.nFixed])
            end

            # Update kpis and requestbank
            eventsInsertedByALNS += insertedByALNS 
            notServicedExpected = length(requestBank[requestBank .> scenario.nFixed])
            requestBank = requestBank[requestBank .<= scenario.nFixed]
            nNotServicedExpectedRequests += notServicedExpected
            solution.totalCost -= notServicedExpected*scenario.taxiParameterExpected
        else
            solution = copySolution(currentState.solution)
        end

        endTimeEvent = time()
        averageResponseTime += endTimeEvent - startTimeEvent

  
        # TODO: jas 
        if closestVehicle != -1 
            closestSchedule = solution.vehicleSchedules[closestVehicle]

            isInsertedIntoClosestVehicle = false
            for assignment in closestSchedule.route
                if assignment.activity.id == event.id
                    isInsertedIntoClosestVehicle = true
                    break
                end
            end

            push!(isInsertedIntoClosestVehicle,isInsertedIntoClosestVehicle)
        end


        # ALNS removes waiting activity at end of route, so we have to add it again
        if event.id != 0
            schedulesToRelocate = addWaitingActivitiesAtEndOfRouteAfterALNS(solution,scenario,relocateVehicles)

            # Relocate vehicles if needed
            if relocateVehicles
                relocateVehicles!(scenario.time,scenario.distance,nRequests,scenario.grid,scenario.depotLocations,predictedDemand,probabilityGrid,solution,schedulesToRelocate,finalSolution,event.callTime,nTimePeriods,periodLength,displayPlots,scenarioName,relocateWithDemand,gamma)
            end
        end
    
        # Test solution using anticipation
        if testALNS
            averageNotServicedExpectedRequests[itr], averageNotServicedExpectedRequestsRelevant[itr] = testSolutionAnticipation(event.request,solution,requestFile,vehiclesFile,parametersFile,scenarioName,nExpected,gridFile,visitedRoute=visitedRoute)
        end

        if printResults
            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Solution after online: ")
            println("----------------")
            printSolution(currentState.solution,printRouteHorizontal)
        end


        # TODO: jas 
        if event.id in requestBank
            inRequestBank = event.id in requestBank  
            timeString = getTimeAsString(event.callTime)

            if event.id == 0 
                title = "Current Solution, Relocation event, time: "*timeString
            else
                title = "Current Solution, Request: "*string(event.id)*", time: "*timeString
            end  

            p1 = createGantChartOfSolutionOnline(solution,title,nRequests,eventId = event.id,eventTime = event.callTime,nFixed = scenario.nFixed,inRequestBank=inRequestBank,event=event.request)
            p2 = plotRoutesOnline(solution,scenario,requestBank,event.request,title)
            savefig(p1,"tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/CurrentSolutionTime"*string(event.callTime)*".png")
            savefig(p2,"tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/CurrentSolutionTime"*string(event.callTime)*"Route.png")
        end

        if displayPlots
            inRequestBank = event.id in requestBank  
            timeString = getTimeAsString(event.callTime)

            if event.id == 0 
                title = "Current Solution, Relocation event, time: "*timeString
            else
                title = "Current Solution, Request: "*string(event.id)*", time: "*timeString
            end  

            p1 = createGantChartOfSolutionOnline(solution,title,nRequests,eventId = event.id,eventTime = event.callTime,nFixed = scenario.nFixed,inRequestBank=inRequestBank,event=event.request)
            p2 = plotRoutesOnline(solution,scenario,requestBank,event.request,title)
            display(p1)
            display(p2)
            savefig(p1,"tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/CurrentSolutionTime"*string(event.callTime)*".pdf")
            savefig(p2,"tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/CurrentSolutionTime"*string(event.callTime)*"Route.png")
        end
    end

    # Update final solution with last state 
    mergeCurrentStateIntoFinalSolution!(finalSolution,solution,scenario)

    # If we have kept the expected requests, we need to remove them from solution
    if keepExpectedRequests
        removeExpectedRequestsFromSolution!(scenario.time,scenario.distance,scenario.serviceTimes,scenario.requests,finalSolution,scenario.nExpected,scenario.nFixed,nNotServicedExpectedRequests,requestBank,scenario.taxiParameter,scenario.taxiParameterExpected)
        # Add again because removed in removeExpectedRequestsFromSolution
        finalSolution.nTaxiExpected += nNotServicedExpectedRequests
        finalSolution.totalCost += nNotServicedExpectedRequests * scenario.taxiParameterExpected
    end

    endSimulation = time()
    totalElapsedTime = endSimulation - startSimulation
    averageResponseTime /= length(scenario.onlineRequests)

    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Final solution after merge: ")
        println("----------------")
        printSolution(finalSolution,printRouteHorizontal)
        println("Request bank: ", requestBank)
    end
    if displayPlots
        p = createGantChartOfSolutionOnline(finalSolution,"Final Solution after merge",nRequests,nFixed=scenario.nFixed)
        display(p)
        savefig(p, "tests/WaitingPlots/"*scenarioName*"/"*string(relocateVehicles)*"_"*string(relocateWithDemand)*"/final_solution_gantt.png")
        display(plotRoutes(finalSolution,scenario,requestBank,"Final solution after merge"))
        display(createGantChartOfSolutionOnlineComparison(finalSolution, initialSolution,"Comparison between initial and final solution"))
    end

    if ALNS == false
        servicedRequests = []
        for(vehicle, schedule) in enumerate(finalSolution.vehicleSchedules)
            for activity in schedule.route
                if activity.activity.activityType == PICKUP
                    push!(servicedRequests,activity.activity.id)
                end
            end
        end
        ids = [req.id for req in scenario.requests]
        requestBank = setdiff(ids,servicedRequests)
    end

    # Print summary 
    println(rpad("Metric", 40), "Value")
    println("-"^45)
    println(rpad("Unserviced offline requests", 40), length(requestBankOffline),"/",(length(scenario.offlineRequests)-scenario.nExpected))
    println(rpad("Unserviced online requests", 40), length(setdiff(requestBank, requestBankOffline)),"/",length(scenario.onlineRequests))
    println(rpad("Final cost", 40), finalSolution.totalCost)
    println(rpad("Final distance", 40), finalSolution.totalDistance)
    println(rpad("Final ride time (veh)", 40), finalSolution.totalRideTime)
    println(rpad("Final idle time", 40), finalSolution.totalIdleTime)
    println(rpad("Total elapsed time (sim)", 40),totalElapsedTime)
    println(rpad("Average response time (sim)", 40),averageResponseTime)
    println(rpad("Events inserted by ALNS", 40),eventsInsertedByALNS)
    if keepExpectedRequests
        println(rpad("Unserviced expected requests offline", 40), nNotServicedExpectedRequestsOffline,"/",scenario.nExpected)
        println(rpad("Unserviced expected requests online", 40), nNotServicedExpectedRequests-nNotServicedExpectedRequestsOffline)
    end

    # TODO: jas 
    #Box plot of drive time to nearest idle vehicle
    if length(driveTimeToNearestIdleVehicleVector) > 0
        p = boxplot(driveTimeToNearestIdleVehicleVector;
            title = "Drive Time to Nearest Idle Vehicle",
            ylabel = "Drive Time (s)",
            xlabel = "",
            legend = false,
            linewidth = 2,
            fillalpha = 0.5,
            markercolor = :blue,
            linecolor = :black,
            boxcolor = :steelblue,
            outliercolor = :black,
            whiskerwidth = 1.5,
            grid = false,
            framestyle = :box,
            yguidefont = font(14),
            titlefont = font(16, "Arial"),
            xtickfontsize = 10,
            ytickfontsize = 12,
            yticks = 0:5:maximum(driveTimeToNearestIdleVehicleVector),
            size = (600, 400)
        )

        display(p)
        savefig(p, "tests/WaitingPlots/" * scenarioName * "/" * string(relocateVehicles) * "_" * string(relocateWithDemand) * "/drive_time_to_nearest_idle_vehicle.png")

        df = DataFrame(request_id = requestIds,drive_time = driveTimeToNearestIdleVehicleVector,isInsertedIntoClosestVehicle = isInsertedIntoClosestVehicle,closestVehicleOverlap = closestVehicleOverlapVector,numberOfVehiclesOverlap = numberOfVehiclesOverlapVector)
        CSV.write("tests/WaitingPlots/" * scenarioName * "/" * string(relocateVehicles) * "_" * string(relocateWithDemand) * "/drive_time_to_nearest_idle_vehicle.csv", df)

        df = DataFrame(request_bank = requestBank)
        CSV.write("tests/WaitingPlots/" * scenarioName * "/" * string(relocateVehicles) * "_" * string(relocateWithDemand) * "/requestBank.csv", df)
    end



    if saveResults
        if !isdir(outPutFileFolder)
            mkpath(outPutFileFolder)
        end
        fileName = outPutFileFolder*"/Simulation_KPI_"*string(scenario.name)*"_"*string(relocateVehicles)*"_"*string(relocateWithDemand)*".json"
        KPIDict = writeOnlineKPIsToFile(fileName,scenario,finalSolution,requestBank,requestBankOffline,totalElapsedTime,averageResponseTime,eventsInsertedByALNS,numberOfRequestsOverlapIdleVehicle,driveTimeToNearestIdleVehicle)
        println("=== KPI Summary ===")
        for (key, value) in KPIDict
            println(rpad(key, 30), ": ", value)
        end

        # Save test solution results anticipation
        if testALNS
            fileName = outPutFileFolder*"/testSolutionAnticipation_KPI_"*string(scenario.name)*".csv"
            testSolutionResults = DataFrame(
                callTimes = [event.callTime for event in events],
                averageNotServicedExpectedRequests = averageNotServicedExpectedRequests,
                averageNotServicedExpectedRequestsRelevant = averageNotServicedExpectedRequestsRelevant
            )
            CSV.write(fileName, testSolutionResults)
        end

        if keepExpectedRequests
            fileName = outPutFileFolder*"/whatHappensToExpectedRequests_"*string(scenario.name)*".json"
            file = open(fileName, "w") 
            write(file, JSON.json(whatHappensToExpected))
            close(file)
        end

    end
    
    if keepExpectedRequests
        state = State(finalSolution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state,nExpected = nExpected)
        @test msg == ""
        @test feasible == true
    else
        state = State(finalSolution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test msg == ""
        @test feasible == true
    end

    updateIds!(finalSolution,scenario.nFixed,scenario.nExpected)

    return finalSolution, requestBank

end


end