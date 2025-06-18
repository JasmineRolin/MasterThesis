module RelocateVehicleUtils

using domain, utils 
using UnPack, Random 
using ..GeneratePredictedDemand
using StatsBase 

export determineWaitingLocation,determineActiveVehiclesPrCell,determineVehicleBalancePrCell,determineWaitingLocation2, determineActiveVehiclesPrCell

#==
 Method to determine waiting location of a vehicle
==#
function determineWaitingLocation2(time::Array{Int,2},nRequests::Int,depotLocations::Dict{Tuple{Int,Int},Location},grid::Grid,probabilityGrid::Array{Float64,2}, activeVehiclesPrCell::Array{Int,3},period::Int,currentGridCell::Tuple{Int,Int},currentWaitingId::Int,activityBeforeWaitingId::Int,isRouteEmpty::Bool,endOfServiceActivityBeforeWaiting::Int,periodLength::Int,nTimePeriods::Int)

    # Active vehicles in period
    activeVehiclesInPeriod = activeVehiclesPrCell[period, :, :]

    # Find time between current cell and depot locations
    nRows, nCols = size(probabilityGrid)
    driveTimeMatrix = zeros(nRows, nCols)
    score = zeros(nRows, nCols)

    # Compute drive times to each depot location from previous activity 
    for r in 1:nRows, c in 1:nCols
        depotId = findDepotIdFromGridCell(grid, nRequests, (r, c))
        driveTimeMatrix[r, c] = time[activityBeforeWaitingId, depotId]
    end

    # Avoid division by zero or extremely small numbers
    driveTimeMatrix .+= 1.0

    # Calculate utility (?)/weighted probability 
    score = probabilityGrid ./ (activeVehiclesInPeriod .+ 1) ./ driveTimeMatrix

    # Find max score 
    argMaxIdx = argmax(score)
    maxRowIdx = argMaxIdx[1]
    maxColIdx = argMaxIdx[2]

    # Find depot location
    depotId = findDepotIdFromGridCell(grid, nRequests, (maxRowIdx, maxColIdx))

    println("----- relocation ------")
    println("From cell: ", currentGridCell)
    println("To cell: ", (maxRowIdx, maxColIdx))
    println("Max score: ", score[maxRowIdx, maxColIdx])
    println("Number of vehicles in cell: ", activeVehiclesInPeriod[maxRowIdx, maxColIdx])
    println("Probability in cell: ", probabilityGrid[maxRowIdx, maxColIdx])

    return depotId,depotLocations[(maxRowIdx,maxColIdx)],(maxRowIdx,maxColIdx), score
end

function determineWaitingLocation(time::Array{Int,2},depotLocations::Dict{Tuple{Int,Int},Location},grid::Grid,nRequests::Int, vehicleBalance::Array{Int,3},period::Int,currentWaitingId::Int)
    # Determine cell with most deficit of vehicles
    vehicleBalanceInPeriod = vehicleBalance[period, :, :]

   # println("Vehicle balance in period: \n", vehicleBalanceInPeriod)

    # Find the minimum value
    minValue = minimum(vehicleBalanceInPeriod)
    println("Minimum value: ", minValue)

    # Get all indices where the value equals the minimum
    minIndices = findall(x -> x == minValue, vehicleBalanceInPeriod)

    # Retrive all depots ids for minimum values 
    depotIds = [findDepotIdFromGridCell(grid, nRequests, (idx[1], idx[2])) for idx in minIndices]

    # Retrieve drive times to depot ids 
    times = [time[currentWaitingId,d] for d in depotIds]

    # Find depots with minimum drive time
    minTimeIdx = argmin(times)
    minRowIdx = minIndices[minTimeIdx][1]
    minColIdx = minIndices[minTimeIdx][2]
    depotId = depotIds[minTimeIdx]

    return depotId,depotLocations[(minRowIdx,minColIdx)],(minRowIdx,minColIdx)
end

#==
 Method to determine vehicle balance in grid cells
==#
function determineVehicleBalancePrCell(grid::Grid,gamma::Float64,predictedDemand::Array{Float64,3},solution::Solution,nTimePeriods::Int,periodLength::Int)
    # unpack grid 
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 
    
    # Initialize vehicle balance
    vehicleBalance = zeros(Int,nTimePeriods,nRows,nCols)
    vehicleDemand = zeros(Int,nTimePeriods,nRows,nCols)
    realisedDemand = zeros(Int,nTimePeriods,nRows,nCols)
    maxDemandInHorizon = zeros(Float64,nTimePeriods,nRows,nCols)
    activeVehiclesPerCell = zeros(Int,nTimePeriods,nRows,nCols) 

    planningHorizon = 4

    # Find vehicle balance for each hour
    # TODO: update to only be future time periods 
    for period in 1:nTimePeriods
        # Determine minutes
        startOfPeriodInMinutes = (period - 1) * periodLength
        endOfPeriodInMinutes = period * periodLength

        # Determine currently planned active vehicles pr. cell  
        activeVehiclesPerCell[period,:,:],realisedDemand[period,:,:] = determineActiveVehiclesAndDemandPrCell(solution,endOfPeriodInMinutes,startOfPeriodInMinutes,minLat,minLong,nRows,nCols,latStep,longStep)

        # Determine vehicle demand in period
        endPeriod = min(period + planningHorizon, nTimePeriods)
        vehicleDemandInPeriod,maxDemandInHorizonPeriod = generatePredictedVehiclesDemandInHorizon(gamma,predictedDemand,period,endPeriod)
        vehicleDemand[period,:,:] = vehicleDemandInPeriod
        maxDemandInHorizon[period,:,:] = maxDemandInHorizonPeriod

        # Determine surplus/deficit of vehicles in grid cells
        # Use maximum of predicted demand and realised demand (worst case scenario ?)
        vehicleBalance[period,:,:] = activeVehiclesPerCell[period,:,:] .- vehicleDemandInPeriod
    end
   
    return vehicleBalance, activeVehiclesPerCell, realisedDemand, vehicleDemand, maxDemandInHorizon
end


function determineActiveVehiclesPrCell(grid::Grid,solution::Solution,nTimePeriods::Int,periodLength::Int)
    # unpack grid 
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 
    
    # Initialize vehicle balance
    realisedDemand = zeros(Int,nTimePeriods,nRows,nCols)
    activeVehiclesPerCell = zeros(Int,nTimePeriods,nRows,nCols) 


    # Find vehicle balance for each hour
    # TODO: update to only be future time periods 
    for period in 1:nTimePeriods
        # Determine minutes
        startOfPeriodInMinutes = (period - 1) * periodLength
        endOfPeriodInMinutes = period * periodLength

        # Determine currently planned active vehicles pr. cell  
        activeVehiclesPerCell[period,:,:],realisedDemand[period,:,:] = determineActiveVehiclesAndDemandPrCell(solution,endOfPeriodInMinutes,startOfPeriodInMinutes,minLat,minLong,nRows,nCols,latStep,longStep)
    end
   
    return activeVehiclesPerCell
end

function determineActiveVehiclesAndDemandPrCell(solution::Solution,endOfPeriodInMinutes::Int,startOfPeriodInMinutes::Int,minLat::Float64,minLong::Float64, nRows::Int,nCols::Int,latStep::Float64,longStep::Float64)
    # Initialize surplus/deficit of vehicles 
    activeVehiclesPerCell = zeros(Int,nRows,nCols)

    # Initializse actual demand 
    realisedDemand = zeros(Int,nRows,nCols)

    # Go through current solution and determine current vehicles and demand in grid cells
    for schedule in solution.vehicleSchedules
        vehicle = schedule.vehicle
        route = schedule.route

        # If there is no overlap in the available time window and the hour 
        if vehicle.availableTimeWindow.startTime > endOfPeriodInMinutes || vehicle.availableTimeWindow.endTime < startOfPeriodInMinutes
            continue
        end
      

        # Check first and last activity in schedule
        if route[1].startOfServiceTime > endOfPeriodInMinutes || route[end].endOfServiceTime < startOfPeriodInMinutes
            continue
        end

        # Active grid cells in the hour
        activeGridCells = Set{Tuple{Int,Int}}()

        # Find activity assignments in hour 
        for a in route
            # If activity is not in the hour 
            if a.startOfServiceTime > endOfPeriodInMinutes || a.endOfServiceTime < startOfPeriodInMinutes
                continue
            end
       
            # Find grid cell of activity 
            rowIdx, colIdx = determineGridCell(a.activity.location.lat, a.activity.location.long, minLat, minLong, nRows, nCols, latStep, longStep)

            # Add grid cell to set of active grid cells
            push!(activeGridCells, (rowIdx, colIdx))

            # Update demand 
            if a.activity.activityType == PICKUP
                realisedDemand[rowIdx,colIdx] += 1
            elseif a.activity.activityType == DROPOFF
              #  realisedDemand[rowIdx,colIdx] -= 1

                realisedDemand[rowIdx,colIdx] -= 0
            end
        end

        # Update current vehicles in grid cell 
        for (rowIdx, colIdx) in activeGridCells
            activeVehiclesPerCell[rowIdx,colIdx] += 1
        end
    end

    return activeVehiclesPerCell, realisedDemand

end

end