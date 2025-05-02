module GeneratePredictedDemand

using CSV, DataFrames, JSON, domain, UnPack

export generatePredictedDemand,generatePredictedVehiclesDemand

#==
 Method to generate predicted demand  
==#
# TODO: jas - do something else than plain average
function generatePredictedDemand(grid::Grid, historicRequestFiles::Vector{String})
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    nHours = 24
    demandGrid = zeros(Int, nHours, nRows, nCols)
    nFiles = length(historicRequestFiles)

    for requestFile in historicRequestFiles
        df = CSV.read(requestFile, DataFrame)

        for row in eachrow(df)
            lat = row.pickup_latitude
            lon = row.pickup_longitude

            # TODO: jas - only true for pick-up requests - need to use calc. time window for drop off requests 
            hour = Int(ceil(row.request_time / 60))

            rowIdx, colIdx = determineGridCell(lat, lon, minLat, minLong, nRows, nCols, latStep, longStep)

            demandGrid[hour, rowIdx, colIdx] += 1
        end
    end

    averageDemand = demandGrid ./ nFiles

    return averageDemand  # shape: 24 × nRows × nCols
end


#==
 Generate predicted demand of vehicles 
==#
function generatePredictedVehiclesDemand(grid::Grid,gamma::Float64, averageDemand::Array{Float64,3})
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    nHours = 24 
    vehicleDemand = zeros(Int,nHours,nRows,nCols)

    # Find predicted vehicle demand for each hour 
    for h in 1:nHours 
        vehicleDemand[h,:,:] = Int.(ceil.(averageDemand[h,:,:].*gamma))
    end 

    return vehicleDemand
end


end