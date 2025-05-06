module RelocateVehicleUtils

using domain 
using UnPack 

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
function determineVehicleBalancePrCell(grid::Grid,vehicleDemand::Array{Int,3},solution::Solution,nTimePeriods::Int,periodLength::Int)
    # unpack grid 
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    # TODO: do not include current schedule ? 
    # TODO: account for current planned demand 

    # Initialize vehicle balance
    vehicleBalance = zeros(Int,nTimePeriods,nRows,nCols)
    activeVehiclesPerCell = zeros(Int,nTimePeriods,nRows,nCols) # TODO: remove returning this (only for test)

    # Find vehicle balance for each hour
    for period in 1:nTimePeriods
        # Determine minutes
        startOfPeriodInMinutes = (period - 1) * periodLength
        endOfPeriodInMinutes = period * periodLength

        # Vehicle demand in hour 
        vehicleDemandInHour = vehicleDemand[period,:,:]

        # Determine currently planned active vehicles pr. cell  
        activeVehiclesPerCell[period,:,:] = determineActiveVehiclesPrCell(solution,endOfPeriodInMinutes,startOfPeriodInMinutes,minLat,minLong,nRows,nCols,latStep,longStep)

        # Determine surplus/deficit of vehicles in grid cells
        vehicleBalance[period,:,:] = activeVehiclesPerCell[period,:,:] .- vehicleDemandInHour
    end
   
    return vehicleBalance, activeVehiclesPerCell
end

function determineActiveVehiclesPrCell(solution::Solution,endOfPeriodInMinutes::Int,startOfPeriodInMinutes::Int,minLat::Float64,minLong::Float64, nRows::Int,nCols::Int,latStep::Float64,longStep::Float64)
    # Initialize surplus/deficit of vehicles 
    activeVehiclesPerCell = zeros(Int,nRows,nCols)

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
        # TODO: how are we supposed to count this ? Is a vehicle active in all grid cells in the hour ?
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
        end

        # Update current vehicles in grid cell 
        for (rowIdx, colIdx) in activeGridCells
            activeVehiclesPerCell[rowIdx,colIdx] += 1
        end
    end

    return activeVehiclesPerCell

end

end