module RelocateVehicleUtils

using domain 
using UnPack 
using ..GeneratePredictedDemand

export determineWaitingLocation,determineActiveVehiclesPrCell,determineVehicleBalancePrCell

#==
 Method to determine waiting location of a vehicle
==#
# Assuming hour is in the future (?)
# TODO: 
    # Vehicles are being relocated to the depot of the previously relocated vehicle 
function determineWaitingLocation(depotLocations::Dict{Tuple{Int,Int},Location},grid::Grid,nRequests::Int, vehicleBalance::Array{Int,3},period::Int)
    # Determine cell with most deficit of vehicles
    minIndexes = argmin(vehicleBalance[period,:,:])
    minRowIdx = minIndexes[1]
    minColIdx = minIndexes[2]
    depotId = findDepotIdFromGridCell(grid,nRequests,(minRowIdx,minColIdx))

    return depotId,depotLocations[(minRowIdx,minColIdx)],(minRowIdx,minColIdx)
end

#==
 Method to determine vehicle balance in grid cells
==#
function determineVehicleBalancePrCell(grid::Grid,gamma::Float64,predictedDemand::Array{Float64,3},solution::Solution,nTimePeriods::Int,periodLength::Int)
    # unpack grid 
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    # TODO: do not include current schedule ? 
    # TODO: account for current planned demand 

    # Initialize vehicle balance
    vehicleBalance = zeros(Int,nTimePeriods,nRows,nCols)
    vehicleDemand = zeros(Int,nTimePeriods,nRows,nCols)
    realisedDemand = zeros(Int,nTimePeriods,nRows,nCols)
    activeVehiclesPerCell = zeros(Int,nTimePeriods,nRows,nCols) # TODO: remove returning this (only for test)

    # TODO: set correctly 
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
        vehicleDemandInPeriod = generatePredictedVehiclesDemandInHorizon(gamma,predictedDemand,period,endPeriod)
        vehicleDemand[period,:,:] = vehicleDemandInPeriod

        # Determine surplus/deficit of vehicles in grid cells
        # Use maximum of predicted demand and realised demand (worst case scenario ?)
        vehicleBalance[period,:,:] = activeVehiclesPerCell[period,:,:] .- vehicleDemandInPeriod
    end
   
    return vehicleBalance, activeVehiclesPerCell, realisedDemand, vehicleDemand
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
        # TODO: how are we supposed to count this ? Is a vehicle active in all grid cells in the hour ? but only once pr. grid cell ? 
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