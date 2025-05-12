module GeneratePredictedDemand

using CSV, DataFrames, JSON, domain, UnPack
using Statistics, ImageFiltering

export generatePredictedDemand,generatePredictedVehiclesDemand,generatePredictedVehiclesDemandInPeriod,generatePredictedVehiclesDemandInHorizon

#==
 Method to generate predicted demand  
==#
# TODO: jas - do something else than plain average
function generatePredictedDemand(grid::Grid, historicRequestFiles::Vector{String}, nTimePeriods::Int,periodLength::Int)
    @unpack minLat,maxLat,minLong,maxLong, nRows,nCols,latStep,longStep = grid 

    demandGrid = zeros(Float64, nTimePeriods, nRows, nCols)
    nFiles = length(historicRequestFiles)

    for requestFile in historicRequestFiles
        df = CSV.read(requestFile, DataFrame)

        for row in eachrow(df)
            lat = row.pickup_latitude
            lon = row.pickup_longitude

            # Count demand as +1 for pickup and -1 for dropoff
            if row.request_type == 0
                timeVal = row.request_time
            else 
                timeVal = row.request_time- row.direct_drive_time
            end

            # Determine time period 
            period = min(Int(ceil(timeVal / periodLength)), nTimePeriods)

            # Determine grid cell
            rowIdx, colIdx = determineGridCell(lat, lon, minLat, minLong, nRows, nCols, latStep, longStep)

            # Update demand grid 
            demandGrid[period, rowIdx, colIdx] += 1
        end
    end

    averageDemand = demandGrid ./ nFiles
    #averageDemand = smoothSpatial(averageDemand)

    return averageDemand  
end


function smoothSpatial(demandGrid::Array{Float64,3})
    smoothedGrid = similar(demandGrid)

    for t in 1:size(demandGrid, 1)
        smoothedGrid[t, :, :] = imfilter(demandGrid[t,:,:], Kernel.gaussian(0.1));
    end

    return smoothedGrid
end

#==
 Generate predicted capacity of vehicles 
==#
# Assuming homogenous vehicles
function generatePredictedVehiclesDemand(grid::Grid,gamma::Float64, averageDemand::Array{Float64,3},nTimePeriods::Int)
    vehicleDemand = zeros(Int,nTimePeriods,nRows,nCols)

    # Find predicted vehicle demand for each hour 
    for p in 1:nTimePeriods 
        vehicleDemand[p,:,:] = Int.(ceil.(averageDemand[p,:,:].*gamma))
    end 

    return vehicleDemand
end

function generatePredictedVehiclesDemandInPeriod(gamma::Float64, predictedDemand::Array{Float64,2},realisedDemand::Array{Int,2})
   return Int.(ceil.(predictedDemand.*gamma))
end

function generatePredictedVehiclesDemandInHorizon(gamma::Float64, predictedDemand::Array{Float64,3},period::Int,endPeriod::Int)
    # Find predicted vehicle demand for each hour 
    maxDemandInHorizon = maximum(predictedDemand[period:endPeriod,:,:], dims=1)
    maxDemandInHorizon = dropdims(maxDemandInHorizon, dims=1)

    return Int.(ceil.(maxDemandInHorizon.*gamma)), maxDemandInHorizon
end


end