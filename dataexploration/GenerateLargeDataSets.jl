using CSV, DataFrames
using Plots
using KernelDensity
using Random
using StatsBase
using domain 

include("TransformKonsentraData.jl")
include("GenerateLargeVehiclesKonsentra.jl")

global DoD = 0.4 # Degree of dynamism
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global callBuffer = 2*60 # 2 hours buffer
global nData = 10
global nRequest = 20 

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
function getLocationDistribution(location_matrix::Array{Float64, 2})#, x_range::Vector{Float64}, y_range::Vector{Float64})
    # Perform Kernel Density Estimation (KDE) in 2D
    kde = KernelDensity.kde((location_matrix[:,1], location_matrix[:,2]))

    # Create a density grid
    # x_range = range(minimum(x_range), stop=maximum(x_range), length=200)
    # y_range = range(minimum(y_range), stop=maximum(y_range), length=200)

    density_grid = kde.density' # Transpose #[pdf(kde, x, y) for x in x_range, y in y_range]

    epsilon = 0.0001
    density_grid = density_grid .+ epsilon
    dx = step(kde.x)  # Difference between consecutive points
    dy = step(kde.y)
    probabilities = vec(density_grid) * dx * dy / sum(density_grid * dx * dy)

    x_range = collect(kde.x)
    y_range = collect(kde.y)

    return probabilities, density_grid, x_range, y_range
end

function getNewLocations(probabilities::Vector{Float64},x_range::Vector{Float64}, y_range::Vector{Float64})
    # Sample locations based on probabilities
    sampled_indices = sample(1:length(probabilities), Weights(probabilities), 2)
    sampled_locations = [ (x_range[(i - 1) ÷ length(y_range) + 1], y_range[(i - 1) % length(y_range) + 1]) for i in sampled_indices]

    return sampled_locations
end

#==
# Get request time distribution
==#
# TODO: adjust bandwith
function getRequestTimeDistribution(requestTimePickUp::Vector{Int}, requestTimeDropOff::Vector{Int}, time_range::Vector{Int})
    # PICK UP TIME KDE
    kde_pickUpTime = KernelDensity.kde(requestTimePickUp)
    density_values_pickUp = [pdf(kde_pickUpTime, t) for t in time_range]
    epsilon = 0.0001
    density_values_pickUp = density_values_pickUp .+ epsilon
    probabilities_pickUpTime = density_values_pickUp / sum(density_values_pickUp)

    # DROP OFF TIME KDE
    kde_dropOffTime = KernelDensity.kde(requestTimeDropOff)
    density_values_dropOff = [pdf(kde_dropOffTime, t) for t in time_range]
    epsilon = 0.0001
    density_values_dropOff = density_values_dropOff .+ epsilon
    probabilities_dropOffTime = density_values_dropOff / sum(density_values_dropOff)

    return probabilities_pickUpTime, probabilities_dropOffTime, density_values_pickUp, density_values_dropOff
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
        request_time = Int[],
        mobility_type = String[],
        call_time = Int[],
        direct_drive_time = Int[],
    )

    # Loop to generate samples
    for i in 1:nSample
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]


        # Determine type of request
        if rand() < 0.5
            requestType = 0  # pick-up request

            sampled_indices = sample(1:length(probabilities_pickUpTime), Weights(probabilities_pickUpTime), 1)
            sampledTimePick = time_range[sampled_indices]
            requestTime = ceil(sampledTimePick[1])
        else
            requestType = 1  # drop-off request

            # Direct drive time 
            directDriveTime = ceil(haversine_distance(pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude)[2])

            # Earliest request time 
            earliestRequestTime = serviceWindow[1] + directDriveTime + MAX_DELAY
            indices = time_range .>= earliestRequestTime
            nTimes = sum(indices)

            sampled_indices = sample(1:nTimes, Weights(probabilities_dropOffTime[indices]), 1)
            sampledTimeDrop = time_range[indices][sampled_indices]
            requestTime = ceil(sampledTimeDrop[1])
        end

        

        # Append results for the request
        push!(results, (i, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, requestType, requestTime,"WALKING",0,0))
    end

    # Determine pre-known requests
    preKnown = preKnownRequests(results, DoD, serviceWindow, callBuffer)

    # Determine call time
    callTime(results, serviceWindow, callBuffer, preKnown)

    # Write results to CSV
    mkpath(dirname(output_file))
    CSV.write(output_file, results)

    return results
end


function generateDataSets(nRequest,probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range)
    df_list = []
    newDataList = Vector{String}()  
    for i in 1:nData

        # Make requests and save to CSV
        output_file = "Data/Konsentra/"*string(nRequest)*"/GeneratedRequests_"*string(nRequest)*"_" * string(i) * ".csv"
        push!(newDataList, output_file)
        retry_count = 0
        while retry_count < 5
            try
                # Call the function that may throw the error
                results = makeRequests(nRequest, probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range, output_file)
                
                println("Request generation succeeded!")
                push!(df_list,results)
                break  # Exit the loop if successful
        
            catch e
                if occursin("Degree of dynamism too low", sprint(showerror, e))
                    retry_count += 1
                    println("Error encountered: ", e)
                    println("Retrying... Attempt: ", retry_count)
                    sleep(1)  # Optional: Wait a second before retrying
                else
                    rethrow(e)  # Let other errors propagate
                end
            end
            if retry_count == 5
                println("Failed after 5 attempts. Exiting.")
            end
        end

    end

    return newDataList, df_list
end


# Generate vehicles
function generateVehicles(shifts,df_list, probabilities_location, x_range, y_range)
    computeShiftCoverage!(shifts)
    average_demand_per_hour = generateAverageDemandPerHour(df_list)
    generateNumberOfVehiclesKonsentra!(average_demand_per_hour, shifts)
    locations = []
    total_nVehicles = sum(shift["nVehicles"] for shift in values(shifts))
    for i in 1:total_nVehicles
        push!(locations,getNewLocations(probabilities_location,x_range, y_range)[1])
    end
    generateVehiclesKonsentra(shifts, locations,"Data/Konsentra/"*string(nRequest)*"/Vehicles_"*string(nRequest)*".csv")

    return average_demand_per_hour
end


#================================================#
# Generate data 
#================================================#
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
time_range = collect(range(6*60,23*60))
#x_range = collect(range(minimum(location_matrix[:,1]), maximum(location_matrix[:,1]), length=200))  
#y_range = collect(range(minimum(location_matrix[:,2]), maximum(location_matrix[:,2]), length=200))  

# Find time and location distributions
probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff = getRequestTimeDistribution(requestTimePickUp, requestTimeDropOff, time_range)
probabilities_location, density_grid, x_range, y_range = getLocationDistribution(location_matrix)#, x_range, y_range)

# Generate request data 
newDataList, df_list = generateDataSets(nRequest,probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range)


# Generate vehicles
shifts = Dict(
    "Morning"    => Dict("TimeWindow" => [6*60, 12*60], "cost" => 2.0, "nVehicles" => 0, "y" => []),
    "Noon"       => Dict("TimeWindow" => [10*60, 16*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Afternoon"  => Dict("TimeWindow" => [14*60, 20*60], "cost" => 3.0, "nVehicles" => 0, "y" => []),
    "Evening"    => Dict("TimeWindow" => [18*60, 24*60], "cost" => 4.0, "nVehicles" => 0, "y" => [])
)
average_demand_per_hour = generateVehicles(shifts,df_list, probabilities_location, x_range, y_range)
plotDemandAndShifts(average_demand_per_hour,shifts)


# Visualize results 
p1 = heatmap(x_range, y_range, -density_grid, xlabel="Longitude", ylabel="Latitude", title="Location Density Map",c = :RdYlGn,colorbar=false)
scatter!(location_matrix[:,1], location_matrix[:,2], marker=:circle, label="New Locations", color=:blue,markersize=2)
display(p1)

# Plot request time distribution 
requestTimePickUp_hours = requestTimePickUp ./ 60
time_range_hours = time_range ./ 60
probabilities_pickUpTime_scaled = probabilities_pickUpTime .* 60
p2 = histogram(requestTimePickUp_hours, normalize=:pdf, label="Histogram of Given Data", color=:blue)
plot!(time_range_hours, probabilities_pickUpTime_scaled, label="Probability Distribution From KDE", linewidth=2, linestyle=:solid, color=:red)
vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
title!("Pick-up Time Distribution")
xlabel!("Time (Hours)")
ylabel!("Probability Density")
display(p2)

# # Plot histogram and KDE for drop-off time
requestTimeDropOff_hours = requestTimeDropOff ./ 60
time_range_hours = time_range ./ 60
probabilities_dropOffTime_scaled = probabilities_dropOffTime .* 60
p3 = histogram(requestTimeDropOff_hours, normalize=:pdf, label="Histogram of Given Data", color=:blue)
plot!(time_range_hours, probabilities_dropOffTime_scaled, label="Probability Distribution From KDE", linewidth=2, linestyle=:solid, color=:red)
vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
title!("Drop-off Time Distribution")
xlabel!("Time (Hours)")
ylabel!("Probability Density")
display(p3)

#================================================#
# New data 
#================================================#
# newDataList = [ "Data/Konsentra/100/GeneratedRequests_100_1.csv",
# "Data/Konsentra/100/GeneratedRequests_100_2.csv",
# "Data/Konsentra/100/GeneratedRequests_100_3.csv",
# "Data/Konsentra/100/GeneratedRequests_100_4.csv",
# "Data/Konsentra/100/GeneratedRequests_100_5.csv",
# "Data/Konsentra/100/GeneratedRequests_100_6.csv",
# "Data/Konsentra/100/GeneratedRequests_100_7.csv",
# "Data/Konsentra/100/GeneratedRequests_100_8.csv",
# "Data/Konsentra/100/GeneratedRequests_100_9.csv",
# "Data/Konsentra/100/GeneratedRequests_100_10.csv"]

location_matrix_new, requestTimePickUp_new, requestTimeDropOff_new = getOldData(newDataList)
#x_range_new = collect(range(minimum(location_matrix_new[:,1]), maximum(location_matrix_new[:,1]), length=200))  
#y_range_new = collect(range(minimum(location_matrix_new[:,2]), maximum(location_matrix_new[:,2]), length=200))  

probabilities_pickUpTime_new, probabilities_dropOffTime_new, density_pickUp_new, density_dropOff_new = getRequestTimeDistribution(requestTimePickUp_new, requestTimeDropOff_new, time_range)
probabilities_location_new, density_grid_new,x_range_new,y_range_new = getLocationDistribution(location_matrix_new)#, x_range_new, y_range_new)

# Plot request time distribution 
requestTimePickUp_hours_new = requestTimePickUp_new ./ 60
probabilities_pickUpTime_scaled_new = probabilities_pickUpTime_new .* 60
p4 = histogram(requestTimePickUp_hours_new, normalize=:pdf, label="Histogram of Given Data", color=:blue)
plot!(time_range_hours, probabilities_pickUpTime_scaled_new, label="Probability Distribution From KDE", linewidth=2, linestyle=:solid, color=:red)
vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
title!("Pick-up Time Distribution NEW")
xlabel!("Time (Hours)")
ylabel!("Probability Density")
display(p4)

# Plot histogram and KDE for drop-off time
requestTimeDropOff_hours_new = requestTimeDropOff_new ./ 60
probabilities_dropOffTime_scaled_new = probabilities_dropOffTime_new .* 60
p5 = histogram(requestTimeDropOff_hours_new, normalize=:pdf, label="Histogram of Given Data", color=:blue)
plot!(time_range_hours, probabilities_dropOffTime_scaled_new, label="Probability Distribution From KDE", linewidth=2, linestyle=:solid, color=:red)
vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
title!("Drop-off Time Distribution NEW")
xlabel!("Time (Hours)")
ylabel!("Probability Density")
display(p5)

# Histogram of all request times 
min_x = 5
max_x = 24

p6 = histogram(vcat(requestTimeDropOff_hours_new,requestTimePickUp_hours_new), normalize=:pdf, label="Histogram of Given Data", color=:blue,bins=15, size = (900,500))
vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
title!("Request Time Distribution NEW")
xlabel!("Time (Hours)")
ylabel!("Probability Density")
xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
plot!(xticks=xtick_values)
display(p6)

p7 = heatmap(x_range_new, y_range_new, -density_grid_new, xlabel="Longitude", ylabel="Latitude", title="Location Density Map NEW",c = :RdYlGn,colorbar=false)
scatter!(location_matrix_new[:,1], location_matrix_new[:,2], marker=:circle, label="New Locations", color=:blue,markersize=2)
display(p7)




# p6 = heatmap(x_range, y_range, -density_grid, xlabel="Longitude", ylabel="Latitude", title="Location Density Map NEW",c = :RdYlGn,colorbar=false)
# scatter!(location_matrix_new[:,1], location_matrix_new[:,2], marker=:circle, label="New Locations", color=:blue)