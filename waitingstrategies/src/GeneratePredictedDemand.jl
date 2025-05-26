module GeneratePredictedDemand

using CSV, DataFrames, JSON, domain, UnPack, utils
using Statistics, ImageFiltering

export generatePredictedDemand,generatePredictedVehiclesDemand,generatePredictedVehiclesDemandInPeriod,generatePredictedVehiclesDemandInHorizon,getProbabilityGrid


function getProbabilityGrid(scenario::Scenario)

    # Retrieve depot locations 
    depotLocations = scenario.depotLocations
    grid = scenario.grid

    # Retrieve simulation location probabilties
    x_range, y_range, probabilities_location = loadLocationDistribution("Data/Simulation data/")

    ny = length(y_range)

    # Aggregate probabilities for each grid cell
    probabilitiesGrid = zeros(Float64, grid.nRows, grid.nCols)

    for (idx,p) in enumerate(probabilities_location)
        long = x_range[(idx - 1) ÷ ny + 1]
        lat = y_range[(idx - 1) % ny + 1]
        
        cell = findClosestGridCenter(depotLocations, lat, long)

      #  println("Cell: ", cell, " Lat: ", lat, " Long: ", long, " Probability: ", p)

        # Accumulate probabilities in the grid cell
        probabilitiesGrid[cell[1], cell[2]] += p

    end
    
    return probabilitiesGrid
end


function getProbabilityGrid(scenario::Scenario,historicRequestFiles::Vector{String})

    nRows = scenario.grid.nRows
    nCols = scenario.grid.nCols
    minLat = scenario.grid.minLat
    minLong = scenario.grid.minLong
    latStep = scenario.grid.latStep
    longStep = scenario.grid.longStep


    demandGrid = zeros(Float64,nRows, nCols)

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

            # Determine grid cell
            rowIdx, colIdx = determineGridCell(lat, lon, minLat, minLong, nRows, nCols, latStep, longStep)

            # Update demand grid 
            demandGrid[rowIdx, colIdx] += 1
        end
    end

    nRequests = sum(demandGrid)
    probabilitiesGrid = demandGrid ./ nRequests
    
    return probabilitiesGrid
end

#==
 Method to load location distribution data
==#
function loadLocationDistribution(input_dir::String)
    x_range = Float64.(CSV.read(joinpath(input_dir, "x_range.csv"), DataFrame).x)
    y_range = Float64.(CSV.read(joinpath(input_dir, "y_range.csv"), DataFrame).y)
    probabilities_location = coalesce.(Float64.(CSV.read(joinpath(input_dir, "probabilities_location.csv"), DataFrame).probability), 0.0)

    return (
        x_range,
        y_range,
        probabilities_location
    )
end

#==
    Method to find the closest grid center to a given location
==#
function findClosestGridCenter(depotLocations::Dict{Tuple{Int64, Int64}, Location},lat::Float64,long::Float64)
    closestCenter = nothing
    minDist = Inf

    for (cell, loc) in depotLocations
        cellLat, cellLong = loc.lat, loc.long
        dist = haversine_distance(lat, long, cellLat, cellLong)[1]
        if dist < minDist
            minDist = dist
            closestCenter = cell
        end
    end
 
    return closestCenter
end


#==
 Method to generate predicted demand  
==#
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
    return averageDemand  
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