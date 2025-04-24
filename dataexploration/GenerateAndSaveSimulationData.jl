using CSV, DataFrames
using Plots
using KernelDensity, Statistics
using Random
using StatsBase
using domain, utils
using Plots.PlotMeasures

#include("TransformKonsentraData.jl")
#include("GenerateLargeVehiclesKonsentra.jl")
#include("MakeAndSaveDistanceAndTimeMatrix.jl")

global DoD = 0.4 # Degree of dynamism
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global callBuffer = 2*60 # 2 hours buffer
global nData = 1
global nRequest = 20 
global MAX_DELAY = 15 # TODO Astrid I just put something


#==
# Function to calculate the Silverman rule bandwidth
==#
function silverman_bandwidth(data::Vector{T}) where T
    n = length(data)
    σ = std(data)
    iqr = quantile(data, 0.75) - quantile(data, 0.25)
    return 0.9 * min(σ, iqr / 1.34) * n^(-1/5)
end

function silverman_bandwidth_2D(data::Vector{T}) where T
    n = length(data)
    σ = std(data)
    iqr = quantile(data, 0.75) - quantile(data, 0.25)
    return 1.06 * min(σ, iqr / 1.34) * n^(-1/5)
end


#==
# Get old data
==#
function getOldData(Data::Vector{String};checkUnique=true)
    # Collect longitudes and latitudes as Float64
    longitudes = Float64[]
    latitudes = Float64[]
    requestTimeDropOff = Int[]
    requestTimePickUp = Int[]
    distanceDriven = Float64[]
    requests = Tuple{Int,Float64, Float64, Float64, Float64}[]

    for requestFile in Data
        requestsDF = CSV.read(requestFile, DataFrame)


        # Ensure we only use valid Float64 values
        for r in eachrow(requestsDF)
            req = (r.request_type,Float64(r.pickup_latitude), Float64(r.pickup_longitude), Float64(r.dropoff_latitude), Float64(r.dropoff_longitude))

            if !checkUnique || !(req in requests)
                push!(latitudes, Float64(r.pickup_latitude))
                push!(longitudes, Float64(r.pickup_longitude))
                push!(latitudes, Float64(r.dropoff_latitude))
                push!(longitudes, Float64(r.dropoff_longitude))
                push!(distanceDriven, haversine_distance(Float64(r.pickup_latitude), Float64(r.pickup_longitude), Float64(r.dropoff_latitude), Float64(r.dropoff_longitude))[1])

                # Get request time for pick-up or drop-off
                if r.request_type == 0
                    push!(requestTimePickUp, r.request_time)
                else
                    push!(requestTimeDropOff, r.request_time)
                end

                push!(requests, (r.request_type,Float64(r.pickup_latitude), Float64(r.pickup_longitude), Float64(r.dropoff_latitude), Float64(r.dropoff_longitude)))
            end
        end
    end

    location_matrix = hcat(longitudes, latitudes)
    return location_matrix, requestTimePickUp, requestTimeDropOff, requests, distanceDriven
end


#==
# Function to get distributions
==#
function getLocationDistribution(location_matrix::Array{Float64, 2}; bandwidth_factor::Float64=1.0)#, x_range::Vector{Float64}, y_range::Vector{Float64})
    # Extract X and Y coordinates
    x_data, y_data = location_matrix[:,1], location_matrix[:,2]

    # Compute Silverman’s bandwidths for both dimensions
    bw_x = bandwidth_factor * silverman_bandwidth_2D(x_data)
    bw_y = bandwidth_factor * silverman_bandwidth_2D(y_data)

    # Perform Kernel Density Estimation (KDE) using computed bandwidths
    kde = KernelDensity.kde((x_data, y_data); bandwidth=(bw_x, bw_y))

    # Extract density grid
    density_grid = kde.density'

    # Avoid zero probabilities
    epsilon = 0.0001
    density_grid .= density_grid .+ epsilon

    # Compute probabilities (normalize the density grid)
    dx = step(kde.x)
    dy = step(kde.y)
    probabilities = vec(density_grid) * dx * dy / sum(density_grid * dx * dy)

    # Collect ranges for plotting
    x_range = collect(kde.x)
    y_range = collect(kde.y)

    return probabilities, density_grid, x_range, y_range
end

function getDistanceDistribution(distanceDriven::Vector{Float64}; bandwidth_factor::Float64=1.0)
    # Compute Silverman’s bandwidth
    bw_distance = bandwidth_factor * silverman_bandwidth(distanceDriven)

    # Compute KDE with Silverman’s bandwidth
    kde_distance = KernelDensity.kde(distanceDriven; bandwidth=bw_distance)

    # After collecting the range:
    distance_range = collect(kde_distance.x)
    density_values_distance = kde_distance.density

    # Filter out negative distances
    valid_idxs = findall(x -> x ≥ 0, distance_range)

    # Apply the filter
    distance_range = distance_range[valid_idxs]
    density_values_distance = density_values_distance[valid_idxs]

    # Avoid zero probabilities
    epsilon = 0.0001
    density_values_distance .= density_values_distance .+ epsilon

    # Normalize to get probabilities
    probabilities_distance = density_values_distance / sum(density_values_distance)

    return probabilities_distance, density_values_distance, distance_range
end

function getRequestTimeDistribution(requestTimePickUp::Vector{Int}, requestTimeDropOff::Vector{Int}, time_range::Vector{Int}; bandwidth_factor=1.0)
    # Compute Silverman’s bandwidth and apply scaling
    bw_pickup = bandwidth_factor * silverman_bandwidth(requestTimePickUp)
    bw_dropoff = bandwidth_factor * silverman_bandwidth(requestTimeDropOff)

    # Compute KDE with Silverman’s bandwidth
    kde_pickUpTime = KernelDensity.kde(requestTimePickUp; bandwidth=bw_pickup)
    kde_dropOffTime = KernelDensity.kde(requestTimeDropOff; bandwidth=bw_dropoff)

    # Compute density values
    density_values_pickUp = [pdf(kde_pickUpTime, t) for t in time_range]
    density_values_dropOff = [pdf(kde_dropOffTime, t) for t in time_range]

    # Avoid zero probabilities
    epsilon = 0.0001
    density_values_pickUp .= density_values_pickUp .+ epsilon
    density_values_dropOff .= density_values_dropOff .+ epsilon

    # Normalize to get probability distributions
    probabilities_pickUpTime = density_values_pickUp / sum(density_values_pickUp)
    probabilities_dropOffTime = density_values_dropOff / sum(density_values_dropOff)

    return probabilities_pickUpTime, probabilities_dropOffTime, density_values_pickUp, density_values_dropOff
end

#==
# Function to save all simulation data
==#
function run_and_save_simulation(data_files::Vector{String}, output_dir::String, bandwidth_factor_location, bandwidth_factor_time, time_range)
    isdir(output_dir) || mkpath(output_dir)

    # Load your old data locations and time
    location_matrix, requestTimePickUp, requestTimeDropOff,requests, distanceDriven = getOldData(data_files)

    # Find time and location distributions
    probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff = getRequestTimeDistribution(requestTimePickUp, requestTimeDropOff, time_range,bandwidth_factor=bandwidth_factor_time)
    probabilities_location, density_grid, x_range, y_range = getLocationDistribution(location_matrix;bandwidth_factor = bandwidth_factor_location)
    probabilities_distance, density_distance, distance_range = getDistanceDistribution(distanceDriven; bandwidth_factor=bandwidth_factor_location)

    # Save everything
    CSV.write(joinpath(output_dir, "location_matrix.csv"), DataFrame(longitude=location_matrix[:,1], latitude=location_matrix[:,2]))
    CSV.write(joinpath(output_dir, "request_time_pickup.csv"), DataFrame(time=requestTimePickUp))
    CSV.write(joinpath(output_dir, "request_time_dropoff.csv"), DataFrame(time=requestTimeDropOff))

    CSV.write(joinpath(output_dir, "requests.csv"), DataFrame(
        request_type = [r[1] for r in requests],
        pickup_latitude = [r[2] for r in requests],
        pickup_longitude = [r[3] for r in requests],
        dropoff_latitude = [r[4] for r in requests],
        dropoff_longitude = [r[5] for r in requests]
    ))

    CSV.write(joinpath(output_dir, "distance_driven.csv"), DataFrame(distance=distanceDriven))
    CSV.write(joinpath(output_dir, "distance_distribution.csv"), DataFrame(probability=probabilities_distance))
    CSV.write(joinpath(output_dir, "density_distance.csv"), DataFrame(density=density_distance))
    CSV.write(joinpath(output_dir, "distance_range.csv"), DataFrame(distance=distance_range))
    
    CSV.write(joinpath(output_dir, "pickup_time_distribution.csv"), DataFrame(probability=probabilities_pickUpTime))
    CSV.write(joinpath(output_dir, "density_pickup_time.csv"), DataFrame(density=density_pickUp))
    CSV.write(joinpath(output_dir, "dropoff_time_distribution.csv"), DataFrame(probability=probabilities_dropOffTime))
    CSV.write(joinpath(output_dir, "density_dropoff_time.csv"), DataFrame(density=density_dropOff))

    CSV.write(joinpath(output_dir, "x_range.csv"), DataFrame(x=x_range))
    CSV.write(joinpath(output_dir, "y_range.csv"), DataFrame(y=y_range))
    CSV.write(joinpath(output_dir, "density_grid.csv"), DataFrame(density=vec(density_grid)))
    CSV.write(joinpath(output_dir, "probabilities_location.csv"), DataFrame(probability=probabilities_location))

    println("✅ All simulation outputs saved to $output_dir")
end

#================================================#
# Generate simulation data 
#================================================#
oldDataList = ["Data/Konsentra/TransformedData_30.01.csv",
            "Data/Konsentra/TransformedData_06.02.csv",
            "Data/Konsentra/TransformedData_09.01.csv",
            "Data/Konsentra/TransformedData_16.01.csv",
            "Data/Konsentra/TransformedData_23.01.csv",
            "Data/Konsentra/TransformedData_Data.csv"]

# Smooting factors for KDE 
bandwidth_factor_time = 1.5 
bandwidth_factor_location = 1.25

# Set probabilities and time range
time_range = collect(range(6*60,23*60))

#run_and_save_simulation(oldDataList, "Data/Simulation data/", bandwidth_factor_location, bandwidth_factor_time,time_range)