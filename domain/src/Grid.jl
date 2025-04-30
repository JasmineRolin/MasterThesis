module Grids 

using ..Locations

export Grid,determineGridCell,findDepotLocations


struct Grid 
    maxLat::Float64
    minLat::Float64
    maxLong::Float64
    minLong::Float64
    nRows::Int
    nCols::Int
    latStep::Float64
    longStep::Float64
end 

#==
 Method to detmine grid cell of location
==#
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
function findDepotLocations(grid::Grid)
    # Generate grid cell centers
    gridCentersLat = [grid.minLat + (i + 0.5) * grid.latStep for i in 0:grid.nRows-1]
    gridCentersLong = [grid.minLong + (j + 0.5) * grid.longStep for j in 0:grid.nCols-1]

    depotLocations = Dict{Tuple{Int,Int}, Location}()
    for (i, lat) in enumerate(gridCentersLat)
        for (j, lon) in enumerate(gridCentersLong)
            depotLocations[(i, j)] = Location("Cell ($(i),$(j))", lat, lon)
        end
    end

    return depotLocations
end

end 