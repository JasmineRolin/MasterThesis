
module SimulationFramework

using utils
using domain
using offlinesolution
using onlinesolution
using alns
using waitingstrategies

export simulateScenario

struct Event 
    id::Int
    callTime::Int
    request::Request
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
    #currentSchedule.route[end].activity.timeWindow = TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)
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
function updateCurrentScheduleAtSplit!(scenario::Scenario,schedule::VehicleSchedule,vehicle::Int,currentState::State,idx::Int)
    
    # Update visited route
    for i in 1:idx
        if schedule.route[i].activity.activityType == PICKUP
            currentState.visitedRoute[schedule.route[i].activity.requestId] = Dict("PickUpServiceStart" => schedule.route[i].startOfServiceTime, "DropOffServiceStart" => 0)
        elseif schedule.route[i].activity.activityType == DROPOFF
            currentState.visitedRoute[schedule.route[i].activity.requestId]["DropOffServiceStart"] = schedule.route[i].startOfServiceTime
        end
    end

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

    if vehicle == 7 || vehicle == 9 
        println("Total cost: ", currentSchedule.totalCost)
        printRouteHorizontal(currentSchedule)
    end

    return idx, currentSchedule.activeTimeWindow.startTime
end


# ------
# Function to update current state if vehicle is still available but all customers are still being serviced
# ------
function updateCurrentScheduleAvailableKeepEntireRoute(schedule::VehicleSchedule,currentState::State,vehicle::Int)
    # Update current schedule 
    currentState.solution.vehicleSchedules[vehicle] = schedule

    return 0, 0
    
end


# ------
# Function to update waiting activity in route 
# ------
# Assuming waiting activity is the last activity in the route before depot 
function updateLastWaitingActivityInRoute!(time::Array{Int,2},distance::Array{Float64,2},currentSolution::Solution,schedule::VehicleSchedule,currentSchedule::VehicleSchedule,waitingIdx::Int,waitingLocationId::Int,location::Location,activityBeforeWaiting::ActivityAssignment)
    
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

function relocateWaitingActivityBeforeDepot!(time::Array{Int,2},distance::Array{Float64,2},nRequests::Int,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},vehicleBalance::Array{Int,3},activeVehiclesPerCell::Array{Int,3},realisedDemand::Array{Int,3},predictedDemand::Array{Float64,3},
    currentSolution::Solution,schedule::VehicleSchedule,currentSchedule::VehicleSchedule,finalSolution::Solution,nTimePeriods::Int,periodLength::Int,vehicleDemand::Array{Int,3},displayPlots::Bool)
    
    vehicle = schedule.vehicle
    currentRouteLength = length(currentSchedule.route)
    waitingIdx = currentRouteLength - 1
    finalSchedule = finalSolution.vehicleSchedules[vehicle.id]
    previousWaitingLocation = currentSchedule.route[waitingIdx].activity.location
    previousWaitingLocationId = currentSchedule.route[waitingIdx].activity.id


    # Determine relocation time 
    # TODO: hvilken tid skal det være ? 
    relocationTime = currentSchedule.route[waitingIdx].startOfServiceTime

    # Determine period 
    period = min(Int(ceil(relocationTime / periodLength)), nTimePeriods)

    if all(vehicleBalance[period,:,:] .>= 0)
        previousGridCell = determineGridCell(previousWaitingLocation,grid)

        println("==> No relocation needed for vehicle ",vehicle.id," in period ",period, " minimum: ",minimum(vehicleBalance[period,:,:]), " maximum predicted demand: ", maximum(predictedDemand[period,:,:]))
        if displayPlots
            display(plotRelocation(predictedDemand,activeVehiclesPerCell,realisedDemand,vehicleBalance,previousGridCell,previousGridCell,period,periodLength,vehicle.id,vehicleDemand))
        end
        
        return
    end

    # Find waiting location
    waitingLocationId,waitingLocation,gridCell = determineWaitingLocation(depotLocations,grid,nRequests,vehicleBalance,period,predictedDemand)

    # Determine previous activity 
    if currentRouteLength == 2 # If only waiting and depot left in current schedule 
        activityBeforeWaiting = finalSchedule.route[end]
    else
        activityBeforeWaiting = currentSchedule.route[waitingIdx-1]
    end

    println("==> Waiting location: ",waitingLocationId, ", period: ",period, ", relocation time: ",relocationTime) 
    tttt = activityBeforeWaiting.endOfServiceTime + time[activityBeforeWaiting.activity.id,waitingLocationId] + time[waitingLocationId,vehicle.depotId]
    println("Activity before waiting: ",activityBeforeWaiting.activity.id, " arrival with new: ",tttt, " end time: ",vehicle.availableTimeWindow.endTime)

    if waitingLocationId == previousWaitingLocationId
        println("Did not relocate vehicle ",vehicle.id," as same depot")
        return
    end
 
  


    # Is there time to relocate vehicle 
    if activityBeforeWaiting.endOfServiceTime + time[activityBeforeWaiting.activity.id,waitingLocationId] + time[waitingLocationId,vehicle.depotId] <= vehicle.availableTimeWindow.endTime

        # Update waiting activity 
        splitTime = updateLastWaitingActivityInRoute!(time,distance,currentSolution,schedule,currentSchedule,waitingIdx,waitingLocationId,waitingLocation,activityBeforeWaiting) 
        
        # Determine previous grid cell 
        previousGridCell = determineGridCell(previousWaitingLocation,grid)

        if displayPlots
            display(plotRelocation(predictedDemand,activeVehiclesPerCell,realisedDemand,vehicleBalance,gridCell,previousGridCell,period,periodLength,vehicle.id,vehicleDemand))
        end

        # Update vehicle balance
        # TODO: skal det opdateres sådan?
        waitingActivityStartTime = currentSchedule.route[waitingIdx].startOfServiceTime
        waitingActivityEndTime = currentSchedule.route[waitingIdx].endOfServiceTime
        waitingStartPeriod = min(Int(ceil(waitingActivityStartTime / periodLength)), nTimePeriods)
        waitingEndPeriod = min(Int(ceil(waitingActivityEndTime / periodLength)), nTimePeriods)

        vehicleBalance[waitingStartPeriod:waitingEndPeriod,previousGridCell[1],previousGridCell[2]] .-= 1
        vehicleBalance[waitingStartPeriod:waitingEndPeriod,gridCell[1],gridCell[2]] .+= 1

        activeVehiclesPerCell[waitingStartPeriod:waitingEndPeriod,previousGridCell[1],previousGridCell[2]] .-= 1
        activeVehiclesPerCell[waitingStartPeriod:waitingEndPeriod,gridCell[1],gridCell[2]] .+= 1

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


        println("Relocating vehicle ",vehicle.id," to waiting location ",waitingLocationId," from depot ",vehicle.depotId, " in period ",period)
        return 
    end
    println("Did not relocate vehicle ",vehicle.id," as no time")
end

#------
# Function to relocate vehicles
#------
function relocateVehicles!(time::Array{Int,2},distance::Array{Float64,2},nRequests::Int,grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},
    vehicleBalance::Array{Int,3},activeVehiclesPerCell::Array{Int,3},realisedDemand::Array{Int,3},predictedDemand::Array{Float64,3},
    currentState::State,solution::Solution,finalSolution::Solution,currentTime::Int,nTimePeriods::Int,periodLength::Int,vehicleDemand::Array{Int,3},displayPlots::Bool)
   
    # Retrieve vehicle schedules in solution 
    vehicleSchedules = solution.vehicleSchedules
    currentVehicleSchedules = currentState.solution.vehicleSchedules

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
        schedule = vehicleSchedules[vehicle.id]

        # Check if vehicle should be relocated 
        # Either the route is completed or the route is "full" and there is no room for waiting activity 
        if  routeLength == 1 || endOfAvailableTimeWindow <= currentTime ||
            (routeLength > 2 && (route[end-1].activity.activityType != WAITING) && route[end].startOfServiceTime == endOfAvailableTimeWindow)
            continue
        end

        # Add waiting to empty route 
        if routeLength == 2 && route[1].activity.activityType == DEPOT && route[end].activity.activityType == DEPOT 
                arrivalAtDepot = currentSchedule.route[1].endOfServiceTime
            
                # Create waiting activity to replace depot activity
                waitingActivity = ActivityAssignment(Activity(vehicle.depotId,-1,WAITING, vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), vehicle,arrivalAtDepot,endOfAvailableTimeWindow)
            
                # Update route with waiting activity 
                currentSchedule.route = vcat([route[1]],[waitingActivity],[route[end]])
               
                currentSchedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
                currentSchedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
                currentSchedule.activeTimeWindow.endTime = endOfAvailableTimeWindow
                currentSchedule.totalTime += endOfAvailableTimeWindow - arrivalAtDepot
                currentSchedule.totalIdleTime += endOfAvailableTimeWindow - arrivalAtDepot
                currentSchedule.numberOfWalking = vcat(currentSchedule.numberOfWalking,[0])
    
                currentState.solution.totalRideTime += endOfAvailableTimeWindow - arrivalAtDepot
                currentState.solution.totalIdleTime += endOfAvailableTimeWindow - arrivalAtDepot
        # Add waiting activity at end of route at depot if necesarry 
        elseif route[end-1].activity.activityType != WAITING
            arrivalAtDepot = currentSchedule.route[end].startOfServiceTime
            endOfAvailableTimeWindow = currentSchedule.vehicle.availableTimeWindow.endTime
        
            # Create waiting activity to replace depot activity
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

            currentState.solution.totalRideTime += endOfAvailableTimeWindow - arrivalAtDepot
            currentState.solution.totalIdleTime += endOfAvailableTimeWindow - arrivalAtDepot
        end

        # Relocate waiting activity 
        relocateWaitingActivityBeforeDepot!(time,distance,nRequests,grid,depotLocations,vehicleBalance,activeVehiclesPerCell,realisedDemand,predictedDemand,
        currentState.solution,schedule,currentSchedule,finalSolution,nTimePeriods,periodLength,vehicleDemand,displayPlots)

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
        newDuration = duration(finalSolution.vehicleSchedules[vehicle].activeTimeWindow) #duration(schedule.activeTimeWindow) TODO fix 
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

end


# ------
# Function to determine current state
# ------
function determineCurrentState(solution::Solution,event::Event,finalSolution::Solution,scenario::Scenario,visitedRoute::Dict{Int,Dict{String,Int}},grid::Grid,depotLocations::Dict{Tuple{Int,Int},Location},predictedDemand::Array{Float64,3};relocateVehicles::Bool=false,nTimePeriods::Int=24,periodLength::Int=60,gamma::Float64=0.5,displayPlots::Bool=false)
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
        print("UPDATING SCHEDULE: ",vehicle)

        # TODO: extract route 

        # Check if vehicle is not available yet or has not started service yet
        if schedule.vehicle.availableTimeWindow.startTime > currentTime || schedule.route[1].startOfServiceTime > currentTime
            idx, splitTime = updateCurrentScheduleNotAvailableYet(schedule,currentState,vehicle)
            print(" - not available yet or not started service yet \n")
        # Check if entire route has been served and vehicle is not available anymore
        elseif schedule.vehicle.availableTimeWindow.endTime < currentTime || length(schedule.route) == 1|| (schedule.route[end-1].endOfServiceTime < currentTime && schedule.route[end].startOfServiceTime == schedule.vehicle.availableTimeWindow.endTime)
            idx, splitTime = updateCurrentScheduleNotAvailableAnymore!(currentState,schedule,vehicle)
            print(" - not available anymore \n")
        # Check if vehicle has not been assigned yet
        elseif length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT
            idx, splitTime = updateCurrentScheduleNoAssignement!(vehicle,currentTime,currentState)
            print(" - no assignments \n")

        # We have completed the last activity and the vehicle is on-route to the depot but still available 
        elseif length(schedule.route) > 1 && schedule.route[end-1].endOfServiceTime < currentTime 
            idx,splitTime = updateCurrentScheduleRouteCompleted!(currentState,schedule,vehicle)
        # TODO: add case to split waiting activitiy if we are relocation vehicles 
           print("- completed route but still available \n")
        else
            # Determine index to split
            didSplit = false
            for (split,assignment) in enumerate(schedule.route)
               if assignment.endOfServiceTime < currentTime && schedule.route[split + 1].endOfServiceTime > currentTime
                    idx, splitTime  = updateCurrentScheduleAtSplit!(scenario,schedule,vehicle,currentState,split)
                    didSplit = true
                   print(" - still available, split at ",split, ", \n")
                    break
                end
            end

            if didSplit == false
                idx, splitTime = updateCurrentScheduleAvailableKeepEntireRoute(schedule,currentState,vehicle)
               print(" - still available, keep entire route, \n")
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

    # Relocate vehicles if relocation event 
    # Relocate vehicles when they have serviced all customers in route 
    if relocateVehicles && event.id == 0
        # Determine current vehicle balance 
        vehicleBalance,activeVehiclesPerCell,realisedDemand, vehicleDemand = determineVehicleBalancePrCell(grid,gamma,predictedDemand,currentState.solution,nTimePeriods,periodLength)

        relocateVehicles!(time,distance,nRequests,grid,depotLocations,
        vehicleBalance,activeVehiclesPerCell,realisedDemand,predictedDemand,
        currentState,solution,finalSolution,currentTime,nTimePeriods,periodLength,vehicleDemand,displayPlots)
    end

    return currentState, finalSolution
end


# ------
# Function to simulate a scenario
# ------
function simulateScenario(scenario::Scenario;printResults::Bool = false,saveResults::Bool=false,displayPlots::Bool=false,outPutFileFolder::String="tests/output",saveALNSResults::Bool = false,displayALNSPlots::Bool = false,historicRequestFiles::Vector{String} = Vector{String}(),gamma::Float64=0.5,relocateVehicles::Bool=false,nTimePeriods::Int=24,periodLength::Int=60)
    # Retrieve info 
    grid = scenario.grid
    depotLocations = scenario.depotLocations
    

    # Generate predicted demand
    if relocateVehicles
        predictedDemand = generatePredictedDemand(grid, historicRequestFiles,nTimePeriods,periodLength)
    else 
        predictedDemand = zeros(Float64,0,0,0)
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

    # Get solution for initial solution (offline problem)
    initialSolution, initialRequestBank = simpleConstruction(scenario,scenario.offlineRequests) 
    
    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Intitial before  ALNS")
        println("----------------")
        printSolution(initialSolution,printRouteHorizontal)
    end
    if displayPlots
        display(createGantChartOfSolutionOnline(initialSolution,"Initial Solution"))
        display(plotRoutes(initialSolution,scenario,initialRequestBank,"Initial Solution"))
    end

    # Run ALNS for offline solution 
    # TODO: set correct parameters for alns
    solution,requestBank = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters_offline.json",initialSolution =  initialSolution, requestBank = initialRequestBank, displayPlots = displayALNSPlots, saveResults = saveALNSResults)
    requestBankOffline = deepcopy(requestBank)

    # Update time windows 
    updateTimeWindowsOnline!(solution,scenario)

    # Print routes
    if printResults
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Intitial after ALNS")
        println("----------------")
        printSolution(solution,printRouteHorizontal)
    end
    if displayPlots
        display(createGantChartOfSolutionOnline(solution,"Initial Solution after ALNS"))
        display(plotRoutes(solution,scenario,requestBank,"Initial Solution after ALNS"))
    end

    # Initialize visited routes 
    visitedRoute = Dict{Int,Dict{String,Int}}()

    # TODO: do in better way 
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
    for (itr,event) in enumerate(events)
        startTimeEvent = time()
        println("------------------------------------------------------------------------------------------------------------------------------------------------")
        println("Event: id: ", itr, ", time: ", event.callTime, " request id: ", event.id, " pick up time: ",event.request.pickUpActivity.timeWindow)
        println("----------------")

        # Determine current state
        currentState, finalSolution = determineCurrentState(solution,event,finalSolution,scenario,visitedRoute,grid,depotLocations,predictedDemand,relocateVehicles=relocateVehicles,gamma=gamma,displayPlots=displayPlots,nTimePeriods=nTimePeriods,periodLength=periodLength)
        
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
        feasible, msg = checkSolutionFeasibilityOnline(scenario,currentState,checkOnline=true)
        if !feasible
            println("INFEASIBLE SOLUTION IN ITERATION:", itr)
            println("nOnline: ", nOnline,"/",length(scenario.onlineRequests))
            println(msg)
            return currentState, requestBank
        end

  
        # Get solution for online problem
        if event.id != 0
            nOnline += 1
            solution, requestBank,insertedByALNS = onlineAlgorithm(currentState, requestBank, scenario, destroyMethods, repairMethods) 
            eventsInsertedByALNS += insertedByALNS 
        else
            solution = copySolution(currentState.solution)
        end

        endTimeEvent = time()
        averageResponseTime += endTimeEvent - startTimeEvent



        if printResults
            println("------------------------------------------------------------------------------------------------------------------------------------------------")
            println("Solution after online: ")
            println("----------------")
            printSolution(currentState.solution,printRouteHorizontal)
        end

        if displayPlots && event.id in requestBank
            display(createGantChartOfSolutionAndEventOnline(solution,"Current Solution, event: "*string(event.id)*", time: "*string(event.callTime),eventId = event.id,eventTime = event.callTime, event=event.request))
            display(plotRoutesOnline(solution,scenario,requestBank,event.request,"Current Solution: event id:"*string(event.id)*" event: "*string(itr)*"/"*string(totalEvents)*", time: "*string(event.callTime)))       
        elseif displayPlots
           display(createGantChartOfSolutionOnline(solution,"Current Solution, event: "*string(event.id)*", time: "*string(event.callTime),eventId = event.id,eventTime = event.callTime))
           display(plotRoutesOnline(solution,scenario,requestBank,event.request,"Current Solution: event id:"*string(event.id)*" event: "*string(itr)*"/"*string(totalEvents)*", time: "*string(event.callTime)))       
        end

    end

    # Update final solution with last state 
    mergeCurrentStateIntoFinalSolution!(finalSolution,solution,scenario)
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
        display(createGantChartOfSolutionOnline(finalSolution,"Final Solution after merge"))
        display(plotRoutes(finalSolution,scenario,requestBank,"Final solution after merge"))
    end


    # Print summary 
    println(rpad("Metric", 40), "Value")
    println("-"^45)
    println(rpad("Unserviced offline requests", 40), length(requestBankOffline),"/",length(scenario.offlineRequests))
    println(rpad("Unserviced online requests", 40), length(setdiff(requestBank, requestBankOffline)),"/",length(scenario.onlineRequests))
    println(rpad("Final cost", 40), finalSolution.totalCost)
    println(rpad("Final distance", 40), finalSolution.totalDistance)
    println(rpad("Final ride time (veh)", 40), finalSolution.totalRideTime)
    println(rpad("Final idle time", 40), finalSolution.totalIdleTime)
    println(rpad("Total elapsed time (sim)", 40),totalElapsedTime)
    println(rpad("Average response time (sim)", 40),averageResponseTime)
    println(rpad("Events inserted by ALNS", 40),eventsInsertedByALNS)

    if saveResults
        if !isdir(outPutFileFolder)
            mkpath(outPutFileFolder)
        end
        fileName = outPutFileFolder*"/Simulation_KPI_"*string(scenario.name)*"_"*relocateVehicles*".json"
        KPIDict = writeOnlineKPIsToFile(fileName,scenario,finalSolution,requestBank,requestBankOffline,totalElapsedTime,averageResponseTime,eventsInsertedByALNS)
        println("=== KPI Summary ===")
        for (key, value) in KPIDict
            println(rpad(key, 30), ": ", value)
        end
    end
    

    return finalSolution, requestBank

end


end