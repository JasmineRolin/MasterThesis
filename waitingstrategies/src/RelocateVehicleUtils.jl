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
function determineWaitingLocation(depotLocations::Dict{Tuple{Int,Int},Location},grid::Grid,nRequests::Int, vehicleBalance::Array{Int,3},hour::Int)
    # Determine cell with most deficit of vehicles
    minIndexes = argmin(vehicleBalance[hour,:,:])
    minRowIdx = minIndexes[1]
    minColIdx = minIndexes[2]
    depotId = findDepotIdFromGridCell(grid,nRequests,(minRowIdx,minColIdx))

    return depotId,depotLocations[(minRowIdx,minColIdx)],(minRowIdx,minColIdx)
end

#==
 Method to determine vehicle balance in grid cells
==#
function determineVehicleBalancePrCell(grid::Grid,vehicleDemand::Array{Int,3},solution::Solution)
    # unpack grid 
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    # TODO: do not include current schedule ? 
    # TODO: account for current planned demand 

    # Initialize vehicle balance
    nHours = 24
    vehicleBalance = zeros(Int,nHours,nRows,nCols)
    activeVehiclesPerCell = zeros(Int,nHours,nRows,nCols) # TODO: remove returning this (only for test)

    # Find vehicle balance for each hour
    for hour in 1:nHours
        # Determine minutes
        startOfHourInMinutes = (hour - 1) * 60
        endOfHourInMinutes = hour * 60

        # Vehicle demand in hour 
        vehicleDemandInHour = vehicleDemand[hour,:,:]

        # Determine currently planned active vehicles pr. cell  
        activeVehiclesPerCell[hour,:,:] = determineActiveVehiclesPrCell(solution,endOfHourInMinutes,startOfHourInMinutes,minLat,minLong,nRows,nCols,latStep,longStep)

        # Determine surplus/deficit of vehicles in grid cells
        vehicleBalance[hour,:,:] = vehicleDemandInHour .- activeVehiclesPerCell[hour,:,:]
    end
   
    return vehicleBalance, activeVehiclesPerCell
end

function determineActiveVehiclesPrCell(solution::Solution,endOfHourInMinutes::Int,startOfHourInMinutes::Int,minLat::Float64,minLong::Float64, nRows::Int,nCols::Int,latStep::Float64,longStep::Float64)
    # Initialize surplus/deficit of vehicles 
    activeVehiclesPerCell = zeros(Int,nRows,nCols)

    # Go through current solution and determine current vehicles and demand in grid cells
    for schedule in solution.vehicleSchedules
        vehicle = schedule.vehicle
        route = schedule.route

        # If there is no overlap in the available time window and the hour 
        if vehicle.availableTimeWindow.startTime > endOfHourInMinutes || vehicle.availableTimeWindow.endTime < startOfHourInMinutes
            continue
        end

        # Check first and last activity in schedule
        if route[1].startOfServiceTime > endOfHourInMinutes || route[end].endOfServiceTime < startOfHourInMinutes
            continue
        end

        # Active grid cells in the hour
        # TODO: how are we supposed to count this ? Is a vehicle active in all grid cells in the hour ?
        activeGridCells = Set{Tuple{Int,Int}}()

        # Find activity assignments in hour 
        for a in route
            # If activity is not in the hour 
            if a.startOfServiceTime > endOfHourInMinutes || a.endOfServiceTime < startOfHourInMinutes
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