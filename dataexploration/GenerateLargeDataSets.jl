using CSV, DataFrames
using Plots
using KernelDensity
using Random, Distributions
using StatsBase

#==
 Get new data
==#

# Paths to your CSV files
Data = [
    "Data/Konsentra/TransformedData_30.01.csv",
    "Data/Konsentra/TransformedData_06.02.csv",
    "Data/Konsentra/TransformedData_09.01.csv",
    "Data/Konsentra/TransformedData_16.01.csv",
    "Data/Konsentra/TransformedData_23.01.csv",
    "Data/Konsentra/TransformedData_Data.csv"
]

# Parameters
nDataSets = 1
nSamples = [100]

# Collect old locations
location_matrix = getOldData(Data)

# Get datasets
for i in 1:nDataSets
    newLocations = getNewLocations(location_matrix, nSamples[i])
end

# Visualize 
heatmap(x_range, y_range, density_grid, xlabel="Longitude", ylabel="Latitude", title="Density Map")
scatter!(newLocations[1, :], newLocations[2, :], marker=:circle, label="New Locations")



#== 
 Get old locations
==#
function getOldData(Data::Vector{String})
    # Collect longitudes and latitudes as Float64
    longitudes = Float64[]
    latitudes = Float64[]
    requestTimeDropOff = Int[]
    requestTimePickUp = Int[]

    for requestFile in Data
        requestsDF = CSV.read(requestFile, DataFrame)

        # Ensure we only use valid Float64 values
        for r in eachrow(requestsDF)
            push!(latitudes, Float64(r.pickup_latitude))
            push!(longitudes, Float64(r.pickup_longitude))
            push!(latitudes, Float64(r.dropoff_latitude))
            push!(longitudes, Float64(r.dropoff_longitude))

            # Get request time
            if r.request_type == 0
                push!(requestTimePickUp, r.request_time)
            else
                push!(requestTimePickUp, r.request_time)
            end
        end
    end

    location_matrix = [longitudes latitudes]

    return location_matrix, requestTimePickUp, requestTimeDropOff
end

#== 
 Function to get new locations from a kernel density estimate (KDE)
==#
function getNewLocations(location_matrix::Array{Int},nSamples::Int)::Array{Float64,2}

    # Perform Kernel Density Estimation (KDE) in 2D
    kde = KernelDensity.kde(location_matrix)

    # Create a density grid
    x_range = range(minimum(longitudes), maximum(longitudes), length=200)
    y_range = range(minimum(latitudes), maximum(latitudes), length=200)
    density_grid = [pdf(kde, x, y) for x in x_range, y in y_range]

    # Sample indices from the grid
    probabilities = vec(density_grid) / sum(density_grid)
    indices = sample(1:length(probabilities), Weights(probabilities), nSamples*2)

    # Map indices back to coordinates
    x_samples = [x_range[(i - 1) ÷ length(y_range) + 1] for i in indices]
    y_samples = [y_range[(i - 1) % length(y_range) + 1] for i in indices]
    newLocations = hcat(x_samples, y_samples)'

    return newLocations, kde
end

#== 
 Get request time 
==#
function getRequestTimeDistribution(requestTimePickUp::Array{Int}, requestTimeDropOff::Array{Int}, startTime::Int, endTime::Int)
    ## PICK UP TIME
    # Perform Kernel Density Estimation (KDE) for 1D data (request times)
    kde_pickUpTime = KernelDensity.kde(requestTimePickUp)
    time_range = range(startTime, maximum(endTime), length=200)

    # Create the probability density values on the time range and get data
    density_values = [pdf(kde_pickUpTime, t) for t in time_range]
    probabilities = density_values / sum(density_values)
    sampled_indices = sample(1:length(probabilities), Weights(probabilities), nSamples)
    sampledTimesPick = [time_range[i] for i in sampled_indices]

    ## DROP OFF TIME
    # Perform Kernel Density Estimation (KDE) for 1D data (request times)
    kde_pickUpTime = KernelDensity.kde(requestTimeDropOff)
    time_range = range(startTime, maximum(endTime), length=200)

    # Create the probability density values on the time range and get data
    density_values = [pdf(kde_pickUpTime, t) for t in time_range]
    probabilities = density_values / sum(density_values)
    sampled_indices = sample(1:length(probabilities), Weights(probabilities), nSamples)
    sampledTimesDropOff = [time_range[i] for i in sampled_indices]

    return sampledTimesPick, kde_pickUpTime, sampledTimesDropOff, kde_pickUpTime

end 

