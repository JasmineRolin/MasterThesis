using CSV, DataFrames
using Plots
using KernelDensity, Statistics
using Random
using StatsBase
using domain, utils
using Plots.PlotMeasures

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
                elseif r.request_type == 1 
                    push!(requestTimeDropOff, r.request_time)
                end

                push!(requests, (r.request_type,Float64(r.pickup_latitude), Float64(r.pickup_longitude), Float64(r.dropoff_latitude), Float64(r.dropoff_longitude)))
            end
        end
    end

    location_matrix = hcat(longitudes, latitudes)
    return location_matrix, requestTimePickUp, requestTimeDropOff, requests, distanceDriven
end


function getNewData(Data::Vector{String};checkUnique=true)
    # Collect longitudes and latitudes as Float64
    longitudes = Float64[]
    latitudes = Float64[]
    requestTimeDropOff_offline = Int[]
    requestTimeDropOff_online = Int[]
    requestTimePickUp_offline = Int[]
    requestTimePickUp_online = Int[]
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
                if r.request_type == 0 && r.call_time > 0
                    push!(requestTimePickUp_online, r.request_time)
                elseif r.request_type == 0 && r.call_time == 0
                    push!(requestTimePickUp_offline, r.request_time)
                elseif r.request_type == 1 && r.call_time > 0
                    push!(requestTimeDropOff_online, r.request_time)
                else
                    push!(requestTimeDropOff_offline, r.request_time)
                end

                push!(requests, (r.request_type,Float64(r.pickup_latitude), Float64(r.pickup_longitude), Float64(r.dropoff_latitude), Float64(r.dropoff_longitude)))
            end
        end
    end

    location_matrix = hcat(longitudes, latitudes)
    return location_matrix, requestTimePickUp_offline, requestTimePickUp_online, requestTimeDropOff_offline, requestTimeDropOff_online, requests, distanceDriven
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

function getDistanceDistribution(distanceDriven::Vector{Float64}; bandwidth_factor::Float64=1.0, min_value = 2, max_value = 70)
    # Compute Silverman’s bandwidth
    bw_distance = bandwidth_factor * silverman_bandwidth(distanceDriven)

    # Compute KDE with Silverman’s bandwidth
    kde_distance = KernelDensity.kde(distanceDriven; bandwidth=bw_distance)

    # After collecting the range:
    distance_range = collect(kde_distance.x)
    density_values_distance = kde_distance.density

    # Filter out negative distances
    valid_idxs = findall(x -> x ≥ 0 &&
                         (isnothing(min_value) || x ≥ min_value) &&
                         (isnothing(max_value) || x ≤ max_value),
                         distance_range)

    # Apply the filter
    distance_range = distance_range[valid_idxs]
    density_values_distance = density_values_distance[valid_idxs]

    # Avoid zero probabilities
    epsilon = 0.005
    density_values_distance .= density_values_distance .+ epsilon

    # Normalize to get probabilities
    probabilities_distance = density_values_distance / sum(density_values_distance)

    return probabilities_distance, density_values_distance, distance_range
end

function getRequestTimeDistribution(requestTimePickUp::Vector{Int}, requestTimeDropOff::Vector{Int}, time_range::Vector{Int}; bandwidth_factor=1.0)
    # Compute Silverman’s bandwidth and apply scaling
    bw_pickup = bandwidth_factor * silverman_bandwidth(requestTimePickUp)
    bw_dropoff = 1.5 * silverman_bandwidth(requestTimeDropOff)

    # Compute KDE with Silverman’s bandwidth
    kde_pickUpTime = KernelDensity.kde(requestTimePickUp; bandwidth=bw_pickup)
    kde_dropOffTime = KernelDensity.kde(requestTimeDropOff; bandwidth=bw_dropoff)

    # Compute density values
    density_values_pickUp = [pdf(kde_pickUpTime, t) for t in time_range]
    density_values_dropOff = [pdf(kde_dropOffTime, t) for t in time_range]

    # Avoid zero probabilities
    epsilon = 0.0001
    density_values_pickUp .= density_values_pickUp .+ epsilon
    density_values_dropOff .= density_values_dropOff .+ 0.0008

    # Normalize to get probability distributions
    probabilities_pickUpTime = density_values_pickUp / sum(density_values_pickUp)
    probabilities_dropOffTime = density_values_dropOff / sum(density_values_dropOff)

    return probabilities_pickUpTime, probabilities_dropOffTime, density_values_pickUp, density_values_dropOff
end


function getOnlineRequestTimeDistribution(probabilities_pickUp::Vector{Float64},probabilities_dropOff::Vector{Float64}, time_range::Vector{Int}; second_peak_center::Int=960, peak_boost=1.5, boost_width=60)
    # Apply a Gaussian weight centered at the second peak
    boost_weights = [1.0 + (peak_boost - 1.0) * exp(-((t - second_peak_center)^2) / (2 * boost_width^2)) for t in time_range]
    
    # Multiply original probabilities by the weights
    adjusted_probs_pickUp = probabilities_pickUp .* boost_weights
    adjusted_probs_dropOff = probabilities_dropOff .* boost_weights

    # Suppress first 2 hours 
    for i in eachindex(time_range)
        if time_range[i] <= 480
            adjusted_probs_pickUp[i] = 0.0
            adjusted_probs_dropOff[i] = 0.0
        end
    end

    # Renormalize to maintain valid probability distribution
    total_pickUp = sum(adjusted_probs_pickUp)
    total_dropOff = sum(adjusted_probs_dropOff)
    if total_pickUp > 0
        adjusted_probs_pickUp ./= total_pickUp
    else
        error("Adjusted distribution has zero total mass — check the inputs.")
    end

    if total_dropOff > 0
        adjusted_probs_dropOff ./= total_dropOff
    else
        error("Adjusted distribution has zero total mass — check the inputs.")
    end

    return adjusted_probs_pickUp, adjusted_probs_dropOff
end

function getOfflineRequestTimeDistribution(probabilities_pickUp::Vector{Float64},probabilities_dropOff::Vector{Float64}, time_range::Vector{Int}; first_peak_center::Int=438, peak_boost=1.5, boost_width=60)
    # Apply a Gaussian weight centered at the first peak
    boost_weights = [1.0 + (peak_boost - 1.0) * exp(-((t - first_peak_center)^2) / (2 * boost_width^2)) for t in time_range]
    
    # Multiply probabilities by the boost weights
    adjusted_probs_pickUp = probabilities_pickUp .* boost_weights
    adjusted_probs_dropOff = probabilities_dropOff .* boost_weights

    # Renormalize to maintain valid probability distribution
    total_pickUp = sum(adjusted_probs_pickUp)
    total_dropOff = sum(adjusted_probs_dropOff)
    if total_pickUp > 0
        adjusted_probs_pickUp ./= total_pickUp
    else
        error("Adjusted distribution has zero total mass — check the inputs.")
    end

    if total_dropOff > 0
        adjusted_probs_dropOff ./= total_dropOff
    else
        error("Adjusted distribution has zero total mass — check the inputs.")
    end

    return adjusted_probs_pickUp, adjusted_probs_dropOff
end

#==
# Function to save all simulation data
==#
function run_and_save_simulation(data_files::Vector{String}, output_dir::String, bandwidth_factor_location, bandwidth_factor_time_offline, bandwidth_factor_time_online, bandwidth_factor_distance, time_range)
    isdir(output_dir) || mkpath(output_dir)

    # Load your old data locations and time
    location_matrix, requestTimePickUp, requestTimeDropOff,requests, distanceDriven = getOldData(data_files)

    # Find time and location distributions
    probabilities_pickUpTime_offline, probabilities_dropOffTime_offline, density_pickUp_offline, density_dropOff_offline = getRequestTimeDistribution(requestTimePickUp, requestTimeDropOff, time_range,bandwidth_factor=bandwidth_factor_time_offline)
    probabilities_pickUpTime_online, probabilities_dropOffTime_online, density_pickUp_online, density_dropOff_online = getRequestTimeDistribution(requestTimePickUp, requestTimeDropOff, time_range,bandwidth_factor=bandwidth_factor_time_online)
    probabilities_location, density_grid, x_range, y_range = getLocationDistribution(location_matrix;bandwidth_factor = bandwidth_factor_location)
    probabilities_distance, density_distance, distance_range = getDistanceDistribution(distanceDriven; bandwidth_factor=bandwidth_factor_distance)
    adj_probabilities_pickUpTime_offline, adj_probabilities_dropOffTime_offline = getOfflineRequestTimeDistribution(probabilities_pickUpTime_offline, probabilities_dropOffTime_offline, time_range)
    adj_probabilities_pickUpTime_online, adj_probabilities_dropOffTime_online = getOnlineRequestTimeDistribution(probabilities_pickUpTime_online, probabilities_dropOffTime_online, time_range)

    #p = histogram(requestTimeDropOff;bins=50,normalize=true,label="Histogram",alpha=0.5,xlabel="Distance Driven",ylabel="Density",title="Distance Driven Distribution")
    #p = plot(time_range, probabilities_dropOffTime_offline;lw=2,color=:red,label="Density Estimate")
    #display(p)

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
    
    CSV.write(joinpath(output_dir, "offline_pickup_time_distribution.csv"), DataFrame(probability=adj_probabilities_pickUpTime_offline))
    CSV.write(joinpath(output_dir, "offline_dropoff_time_distribution.csv"), DataFrame(probability=adj_probabilities_dropOffTime_offline))
    CSV.write(joinpath(output_dir, "online_pickup_time_distribution.csv"), DataFrame(probability=adj_probabilities_pickUpTime_online))
    CSV.write(joinpath(output_dir, "online_dropoff_time_distribution.csv"), DataFrame(probability=adj_probabilities_dropOffTime_online))

    CSV.write(joinpath(output_dir, "x_range.csv"), DataFrame(x=x_range))
    CSV.write(joinpath(output_dir, "y_range.csv"), DataFrame(y=y_range))
    CSV.write(joinpath(output_dir, "density_grid.csv"), DataFrame(density=vec(density_grid)))
    CSV.write(joinpath(output_dir, "probabilities_location.csv"), DataFrame(probability=probabilities_location))

    println("✅ All simulation outputs saved to $output_dir")
end

