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
    # Generate grid cell centers
    gridCentersLat = [grid.minLat + (i + 0.5) * grid.latStep for i in 0:grid.nRows-1]
    gridCentersLong = [grid.minLong + (j + 0.5) * grid.longStep for j in 0:grid.nCols-1]

    depotLocations = Dict{Tuple{Int,Int}, Location}()
    depotCoordinates = Vector{Tuple{Float64,Float64}}()
    for (i, lat) in enumerate(gridCentersLat)
        for (j, lon) in enumerate(gridCentersLong)
            depotId = findDepotIdFromGridCell(grid, nRequests, (i, j))
            depotLocations[(i, j)] = Location("D$(depotId)", lat, lon)
            push!(depotCoordinates,(lat,lon))
        end
    end

    return depotLocations, depotCoordinates
end

#==
 Method to find depot id from grid cell
==#
function findDepotIdFromGridCell(grid::Grid,nRequests::Int,gridCell::Tuple{Int,Int})
    return 2*nRequests + (gridCell[2]-1)*grid.nCols + gridCell[1] 
end

function copyGrid(g::Grid)
    return Grid(
        g.maxLat, g.minLat, g.maxLong, g.minLong,
        g.nRows, g.nCols,
        g.latStep, g.longStep
    )
end

end 