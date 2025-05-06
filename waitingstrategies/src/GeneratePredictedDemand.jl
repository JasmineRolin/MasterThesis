module GeneratePredictedDemand

using CSV, DataFrames, JSON, domain, UnPack

export generatePredictedDemand,generatePredictedVehiclesDemand

#==
 Method to generate predicted demand  
==#
# TODO: jas - do something else than plain average
function generatePredictedDemand(grid::Grid, historicRequestFiles::Vector{String}, nTimePeriods::Int,periodLength::Int)
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    demandGrid = zeros(Int, nTimePeriods, nRows, nCols)
    nFiles = length(historicRequestFiles)

    for requestFile in historicRequestFiles
        df = CSV.read(requestFile, DataFrame)

        for row in eachrow(df)
            lat = row.pickup_latitude
            lon = row.pickup_longitude

            if row.request_type == 0
                # TODO: jas - only true for pick-up requests - need to use calc. time window for drop off requests 
                timeVal = row.request_time
            else 
                timeVal = row.request_time- row.direct_drive_time
            end

            # Determine time period 
            period = min(Int(ceil(timeVal / periodLength)), nTimePeriods)


            rowIdx, colIdx = determineGridCell(lat, lon, minLat, minLong, nRows, nCols, latStep, longStep)

            demandGrid[period, rowIdx, colIdx] += 1
        end
    end

    averageDemand = demandGrid ./ nFiles

    return averageDemand  
end


#==
 Generate predicted demand of vehicles 
==#
function generatePredictedVehiclesDemand(grid::Grid,gamma::Float64, averageDemand::Array{Float64,3},nTimePeriods::Int)
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    vehicleDemand = zeros(Int,nTimePeriods,nRows,nCols)

    # Find predicted vehicle demand for each hour 
    for p in 1:nTimePeriods 
        vehicleDemand[p,:,:] = Int.(ceil.(averageDemand[p,:,:].*gamma))
    end 

    return vehicleDemand
end


end