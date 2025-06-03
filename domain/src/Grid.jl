module Grids 

using ..Locations

export Grid,determineGridCell,findDepotLocations,findDepotIdFromGridCell, copyGrid

# Rows are latitude, columns are longitude
struct Grid 
    maxLat::Float64
    minLat::Float64
    maxLong::Float64
    minLong::Float64
    nRows::Int
    nCols::Int
    latStep::Float64
    longStep::Float64

    function Grid()
        new(0.0, 0.0, 0.0, 0.0, 0, 0, 0.0, 0.0)
    end

    function Grid(maxLat::Float64, minLat::Float64, maxLong::Float64, minLong::Float64, nRows::Int, nCols::Int, latStep::Float64, longStep::Float64)
        new(maxLat, minLat, maxLong, minLong, nRows, nCols, latStep, longStep)
    end

end 

#==
 Method to detmine grid cell of location
==#
function determineGridCell(location::Location,grid::Grid)
    # Unpack grid 
    minLat = grid.minLat
    minLong = grid.minLong
    nRows = grid.nRows
    nCols = grid.nCols
    latStep = grid.latStep
    longStep = grid.longStep

    return determineGridCell(location.lat,location.long,minLat,minLong,nRows,nCols,latStep,longStep)
end

function determineGridCell(latitude::Float64,longitude::Float64,minLat::Float64,minLong::Float64, nRows::Int,nCols::Int,latStep::Float64,longStep::Float64)
    # Find grid cell of activity 
    rowIdx = floor(Int, (latitude - minLat) / latStep)
    colIdx = floor(Int, (longitude - minLong) / longStep)

    rowIdx = clamp(rowIdx + 1, 1, nRows)
    colIdx = clamp(colIdx + 1, 1, nCols)

    return rowIdx,colIdx
end

#==
 Method to find possible depot locations 
==#
function findDepotLocations(grid::Grid,nRequests::Int)
    return findDepotLocations(grid.nRows, grid.nCols, grid.minLat, grid.minLong, grid.latStep, grid.longStep, nRequests)
end

function findDepotLocations(nRows::Int,nCols::Int,minLat::Float64,minLong::Float64,latStep::Float64,longStep::Float64,nRequests::Int)
    gridSize = nRows * nCols
    
    # Generate grid cell centers
    gridCentersLat = [minLat + (i + 0.5) * latStep for i in 0:(nRows-1)]
    gridCentersLong = [minLong + (j + 0.5) * longStep for j in 0:(nCols-1)]

    depotLocations = Dict{Tuple{Int,Int}, Location}()
    depotCoordinates = [(0.0, 0.0) for _ in 1:gridSize]

    for lat in gridCentersLat
        for lon in gridCentersLong
            gridCell = determineGridCell(lat, lon, minLat, minLong, nRows, nCols, latStep, longStep)
            depotIndex = findDepotIdFromGridCell(nCols, gridCell)
            depotId = 2 * nRequests + depotIndex  

            depotLocations[gridCell] = Location("D$(depotId)", lat, lon)
            depotCoordinates[depotIndex] = (lat, lon)
        end
    end

    return depotLocations, depotCoordinates
end




#==
 Method to find depot id from grid cell
==#
function findDepotIdFromGridCell(grid::Grid,nRequests::Int,gridCell::Tuple{Int,Int})
    return findDepotIdFromGridCell(grid.nCols, gridCell) +  2*nRequests 
end

function findDepotIdFromGridCell(grid::Grid,gridCell::Tuple{Int,Int})
    return findDepotIdFromGridCell(grid.nCols, gridCell)
end

function findDepotIdFromGridCell(nCols::Int,gridCell::Tuple{Int,Int})
    return (gridCell[2]-1)* nCols + gridCell[1] 
end


function copyGrid(g::Grid)
    return Grid(
        g.maxLat, g.minLat, g.maxLong, g.minLong,
        g.nRows, g.nCols,
        g.latStep, g.longStep
    )
end

end 