using CSV, DataFrames
using Plots
using KernelDensity
using Random
using StatsBase

#==
# Get old data
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

            # Get request time for pick-up or drop-off
            if r.request_type == 0
                push!(requestTimePickUp, r.request_time)
            else
                push!(requestTimeDropOff, r.request_time)
            end
        end
    end

    location_matrix = hcat(longitudes, latitudes)
    return location_matrix, requestTimePickUp, requestTimeDropOff
end



#==
# Function to get new locations from a kernel density estimate (KDE)
==#
function getLocationDistribution(location_matrix::Array{Float64, 2}, x_range::Vector{Float64}, y_range::Vector{Float64})
    # Perform Kernel Density Estimation (KDE) in 2D
    kde = KernelDensity.kde(location_matrix)

    # Create a density grid
    x_range = range(minimum(x_range), stop=maximum(x_range), length=200)
    y_range = range(minimum(y_range), stop=maximum(y_range), length=200)
    density_grid = [pdf(kde, x, y) for x in x_range, y in y_range]

    # Sample indices from the grid (normalized to probabilities)
    probabilities = vec(density_grid) / sum(density_grid)    

    return probabilities, density_grid
end

function getNewLocations( probabilities::Vector{Float64},x_range::Vector{Float64}, y_range::Vector{Float64})
    # Sample locations based on probabilities
    sampled_indices = sample(1:length(probabilities), Weights(probabilities), 2)
    sampled_locations = [ (x_range[(i - 1) ÷ length(y_range) + 1], y_range[(i - 1) % length(y_range) + 1]) for i in sampled_indices]

    return sampled_locations
end

#==
# Get request time distribution
==#
function getRequestTimeDistribution(requestTimePickUp::Array{Int}, requestTimeDropOff::Array{Int}, startTime::Int, endTime::Int)
    # PICK UP TIME KDE
    kde_pickUpTime = KernelDensity.kde(requestTimePickUp)
    time_range = range(startTime, stop=endTime, length=200)
    density_values_pickUp = [pdf(kde_pickUpTime, t) for t in time_range]
    probabilities_pickUpTime = density_values_pickUp / sum(density_values_pickUp)

    # DROP OFF TIME KDE
    kde_dropOffTime = KernelDensity.kde(requestTimeDropOff)
    density_values_dropOff = [pdf(kde_dropOffTime, t) for t in time_range]
    probabilities_dropOffTime = density_values_dropOff / sum(density_values_dropOff)

    return probabilities_pickUpTime, probabilities_dropOffTime
end

#==
# Make request
==#
function makeRequests(nSample::Int, probabilities_pickUpTime::Vector{Float64}, probabilities_dropOffTime::Vector{Float64}, probabilities_location::Vector{Float64}, time_range::Vector{Int}, x_range::Vector{Float64}, y_range::Vector{Float64}, output_file::String)
    results = DataFrame(
        id = Int[],
        pickup_latitude = Float64[],
        pickup_longitude = Float64[],
        dropoff_latitude = Float64[],
        dropoff_longitude = Float64[],
        request_type = Int[],
        request_time = Int[]
    )

    # Loop to generate samples
    for i in 1:nSample
        # Determine type of request
        if rand() < 0.5
            requestType = 0  # pick-up request
            sampled_indices = sample(1:length(probabilities_pickUpTime), Weights(probabilities_pickUpTime), 1)
            sampledTimePick = time_range[sampled_indices]
            requestTime = sampledTimePick[1]
        else
            requestType = 1  # drop-off request
            sampled_indices = sample(1:length(probabilities_dropOffTime), Weights(probabilities_dropOffTime), 1)
            sampledTimeDrop = time_range[sampled_indices]
            requestTime = sampledTimeDrop[1]
        end

        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]

        # Append results for the request
        push!(results, (i, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, requestType, requestTime))
    end

    # Write results to CSV
    CSV.write(output_file, results)

    return results
end

#== 
# Generate requests and save to CSV
==#
# Load your old data locations and time
location_matrix, requestTimePickUp, requestTimeDropOff = getOldData([
    "Data/Konsentra/TransformedData_30.01.csv",
    "Data/Konsentra/TransformedData_06.02.csv",
    "Data/Konsentra/TransformedData_09.01.csv",
    "Data/Konsentra/TransformedData_16.01.csv",
    "Data/Konsentra/TransformedData_23.01.csv",
    "Data/Konsentra/TransformedData_Data.csv"
])

# Set probabilities and time range
time_range = collect(8*60:22*60)  # Example time range
x_range = collect(range(minimum(location_matrix[:,1]), maximum(location_matrix[:,1]), length=200))  
y_range = collect(range(minimum(location_matrix[:,2]), maximum(location_matrix[:,2]), length=200))  

probabilities_pickUpTime, probabilities_dropOffTime = getRequestTimeDistribution(requestTimePickUp, requestTimeDropOff, 1, 1000)
probabilities_location, density_grid = getLocationDistribution(location_matrix, x_range, y_range)

# Make requests and save to CSV
output_file = "Data/Konsentra/GeneratedRequests.csv"
results = makeRequests(100, probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range, output_file)

# Visualize results (e.g., density heatmap)
heatmap(x_range, y_range, density_grid', xlabel="Longitude", ylabel="Latitude", title="Density Map")
scatter!(results.pickup_longitude, results.pickup_latitude, marker=:circle, label="New Locations")
