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
include("GenerateAndSaveSimulationData.jl")

global DoD = 0.4 # Degree of dynamism
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global callBuffer = 2*60 # 2 hours buffer
global nData = 1
global nRequest = 300 
global MAX_DELAY = 15 # TODO Astrid I just put something


function load_simulation_data(input_dir::String)
    location_df = CSV.read(joinpath(input_dir, "location_matrix.csv"), DataFrame)
    location_matrix = hcat(location_df.longitude, location_df.latitude)

    requestTimePickUp = CSV.read(joinpath(input_dir, "request_time_pickup.csv"), DataFrame).time
    requestTimeDropOff = CSV.read(joinpath(input_dir, "request_time_dropoff.csv"), DataFrame).time

    requests_df = CSV.read(joinpath(input_dir, "requests.csv"), DataFrame)
    requests = [(r.request_type, r.pickup_latitude, r.pickup_longitude, r.dropoff_latitude, r.dropoff_longitude)
                for r in eachrow(requests_df)]

    distanceDriven = CSV.read(joinpath(input_dir, "distance_driven.csv"), DataFrame).distance
    probabilities_distance = CSV.read(joinpath(input_dir, "distance_distribution.csv"), DataFrame).probability
    density_distance = CSV.read(joinpath(input_dir, "density_distance.csv"), DataFrame).density
    distance_range = CSV.read(joinpath(input_dir, "distance_range.csv"), DataFrame).distance

    probabilities_pickUpTime = CSV.read(joinpath(input_dir, "pickup_time_distribution.csv"), DataFrame).probability
    density_pickUp = CSV.read(joinpath(input_dir, "density_pickup_time.csv"), DataFrame).density
    probabilities_dropOffTime = CSV.read(joinpath(input_dir, "dropoff_time_distribution.csv"), DataFrame).probability
    density_dropOff = CSV.read(joinpath(input_dir, "density_dropoff_time.csv"), DataFrame).density

    x_range = CSV.read(joinpath(input_dir, "x_range.csv"), DataFrame).x
    y_range = CSV.read(joinpath(input_dir, "y_range.csv"), DataFrame).y

    density_flat = CSV.read(joinpath(input_dir, "density_grid.csv"), DataFrame).density
    density_grid = reshape(density_flat, length(y_range), length(x_range))'

    probabilities_location = CSV.read(joinpath(input_dir, "probabilities_location.csv"), DataFrame).probability

    println("✅ All simulation data loaded from $input_dir")

    return (
        probabilities_pickUpTime,
        probabilities_dropOffTime,
        density_pickUp,
        density_dropOff,
        probabilities_location,
        density_grid,
        x_range,
        y_range,
        probabilities_distance,
        density_distance,
        distance_range,
        location_matrix,
        requestTimePickUp,
        requestTimeDropOff,
        requests,
        distanceDriven,
    )
end


function find_dropoff(pickup::Tuple{Float64, Float64}, grid_coords::Vector{Tuple{Float64, Float64}},distance_sample::Float64,probabilities::Vector{Float64},x_range::Vector{Float64},y_range::Vector{Float64};tolerance_km::Float64 = 1.0)

    # Compute distances from pickup to all grid coordinates
    distances = [haversine_distance(pickup[2], pickup[1], lat, lon)[1] for (lon, lat) in grid_coords]

    # Find grid indices within tolerance
    candidate_idxs = findall(abs.(distances .- distance_sample) .<= tolerance_km)

    if isempty(candidate_idxs)
    error("No candidates found within tolerance range of sampled distance.")
    end

    # Sample one index based on probabilities
    probability_distances = [probabilities[i] for i in candidate_idxs]
    probabilities_sum = sum(probability_distances)
    probabilities_distance_norm = [p / probabilities_sum for p in probability_distances]
    selected_idx = sample(candidate_idxs, Weights(probabilities_distance_norm))

    return grid_coords[selected_idx][1], grid_coords[selected_idx][2] 
end

function getNewLocations(probabilities::Vector{Float64},x_range::Vector{Float64},y_range::Vector{Float64}, distance_range::Vector{Float64},probabilities_distance::Vector{Float64}; tolerance_km::Float64 = 1.0)
    n = length(probabilities)
    ny = length(y_range)
    nd = length(distance_range)

    # Sample pickup location
    pickup_idx = sample(1:n, Weights(probabilities))
    pickup_x = x_range[(pickup_idx - 1) ÷ ny + 1]
    pickup_y = y_range[(pickup_idx - 1) % ny + 1]

    # Sample target distance
    distance_idx = sample(1:nd, Weights(probabilities_distance))
    sampled_distance = distance_range[distance_idx]
    sampled_distance = max(sampled_distance, 0.1) 

    # Find drop off
    grid_coords = [(x, y) for x in x_range for y in y_range]
    dropoff_x, dropoff_y = find_dropoff((pickup_x, pickup_y), grid_coords, sampled_distance, probabilities, x_range, y_range; tolerance_km=tolerance_km)

    return [(pickup_x, pickup_y), (dropoff_x, dropoff_y)]
end

function getNewLocations(probabilities::Vector{Float64},x_range::Vector{Float64}, y_range::Vector{Float64})
    # Sample locations based on probabilities
    sampled_indices = sample(1:length(probabilities), Weights(probabilities), 2)
    sampled_locations = [ (x_range[(i - 1) ÷ length(y_range) + 1], y_range[(i - 1) % length(y_range) + 1]) for i in sampled_indices]
    return sampled_locations
end

#==
# Make request
==#
function makeRequests(nSample::Int, probabilities_pickUpTime::Vector{Float64}, probabilities_dropOffTime::Vector{Float64}, probabilities_location::Vector{Float64}, time_range::Vector{Int}, x_range::Vector{Float64}, y_range::Vector{Float64}, output_file::String,distance_range::Vector{Float64},probabilities_distance::Vector{Float64})
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
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance)
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


function generateDataSets(nRequest,nData,probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range,distance_range::Vector{Float64},probabilities_distance::Vector{Float64})
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
                results = makeRequests(nRequest, probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range, output_file,distance_range,probabilities_distance)
                
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


#==
# Generate data sets and vehicles
==#
function generateDataSetsAndvehicles(nRequest,nData,shifts,oldDataList,bandwidth_factor_time,bandwidth_factor_location)
    # Load simulation data
    probabilities_pickUpTime,
        probabilities_dropOffTime,
        density_pickUp,
        density_dropOff,
        probabilities_location,
        density_grid,
        x_range,
        y_range,
        probabilities_distance,
        density_distance,
        distance_range,
        location_matrix,
        requestTimePickUp,
        requestTimeDropOff,
        requests,
        distanceDriven= load_simulation_data("Data/Simulation data/")

    # Generate request data 
    newDataList, df_list = generateDataSets(nRequest,nData,probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range,distance_range,probabilities_distance)

    # Generate vehicles 
    average_demand_per_hour = generateVehicles(shifts,df_list, probabilities_location, x_range, y_range)

    return location_matrix, requestTimePickUp, requestTimeDropOff, newDataList, df_list, average_demand_per_hour, probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff, probabilities_location, density_grid, x_range, y_range, requests, distanceDriven
end

#==
# Create plots 
==#
function plotDataSets(x_range,y_range,density_grid,location_matrix,requestTimePickUp,requestTimeDropOff,probabilities_pickUpTime,probabilities_dropOffTime,serviceWindow,prefix::String,distanceDriven)
    min_x = 5
    max_x = 24

    # Visualize results 
    p1 = heatmap(x_range, y_range, -density_grid, xlabel="Longitude", ylabel="Latitude", title=prefix*" Location Density Map",c = :RdYlBu_9,colorbar=false)
    scatter!(location_matrix[:,1], location_matrix[:,2], marker=:circle, label="Locations", color=:blue,markersize=3)

    # Plot request time distribution 
    requestTimePickUp_hours = requestTimePickUp ./ 60
    time_range_hours = time_range ./ 60
    probabilities_pickUpTime_scaled = probabilities_pickUpTime .* 60

    p2 = histogram(requestTimePickUp_hours, normalize=:pdf, label="", color=:blue)
    plot!(time_range_hours, probabilities_pickUpTime_scaled, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red,bins=19)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Pick-up Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    # # Plot histogram and KDE for drop-off time
    requestTimeDropOff_hours = requestTimeDropOff ./ 60
    time_range_hours = time_range ./ 60
    probabilities_dropOffTime_scaled = probabilities_dropOffTime .* 60

    p3 = histogram(requestTimeDropOff_hours, normalize=:pdf, label="", color=:blue)
    plot!(time_range_hours, probabilities_dropOffTime_scaled, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red,bins=19)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Drop-off Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

   
    p4 = histogram(vcat(requestTimeDropOff_hours,requestTimePickUp_hours), normalize=:pdf, label="", color=:blue,bins=19, size = (900,500))
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    p5 = histogram(distanceDriven, normalize=:pdf, label="", color=:blue)
    title!(prefix*" Distance Driven Distribution")
    xlabel!("Driven distance")
    ylabel!("Probability Density")


    return p1,p2,p3,p4,p5
end

# Create gant chart of vehicles and requests
function createGantChartOfRequestsAndVehicles(vehicles, requests, requestBank,titleString)
    p = plot(size=(2000,1200))
    yPositions = []
    yLabels = []
    yPos = 1
    
    for (idx,vehicle) in enumerate(vehicles)
        # Vehicle availability window
        tw = vehicle.availableTimeWindow

        if idx == 1
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=5, label="Vehicle TW", color=:blue)
        else
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=5,label="", color=:blue)
        end

        # Plot vertical dashed lines for start and end of time window
        vline!([tw.startTime], linestyle=:dash, color=:grey, linewidth=2, label="")
        vline!([tw.endTime], linestyle=:dash, color=:grey, linewidth=2, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(vehicle.id)")
        yPos += 1
    end
    
    legendServiced = false 
    legendUnserviced = false
    for (idx,request) in enumerate(requests)
        pickupTW = request.pickUpActivity.timeWindow
        dropoffTW = request.dropOffActivity.timeWindow
        
        # Determine color based on whether request is serviced
        offline = request.callTime == 0 #request.id in requestBank
        colorPickup = offline ? :grey : :palegreen
        colorDropoff = offline ? :black : :green
        marker = request.requestType == PICKUP_REQUEST ? :circle : :square

        # Plot pickup and dropoff window as a bar
        if offline && !legendUnserviced
            legendUnserviced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="Offline Pick-up", color=colorPickup,marker = marker)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5, label="Offline Drop-off", color=colorDropoff, marker = marker)
        elseif !offline && !legendServiced
            legendServiced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="Online Pick-up", color=colorPickup,marker = marker)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5, label="Online Drop-off", color=colorDropoff,marker = marker)
        else
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="", color=colorPickup,marker = marker)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5,label="", color=colorDropoff,marker = marker)
        end 
      
        
        push!(yPositions, yPos)
        push!(yLabels, "Request $(request.id)")
        yPos += 1
    end

    
    
    plot!(p,
        yticks=(yPositions, yLabels),bottom_margin=5mm,
        left_margin=5mm, 
        top_margin=5mm,
        right_margin=5mm,)
    xlabel!("Time (Minutes after Midnight)")
    title!(titleString)

    return p
end


#================================================#
# Generate data 
#================================================#
oldDataList = ["Data/Konsentra/TransformedData_30.01.csv",
            "Data/Konsentra/TransformedData_06.02.csv",
            "Data/Konsentra/TransformedData_09.01.csv",
            "Data/Konsentra/TransformedData_16.01.csv",
            "Data/Konsentra/TransformedData_23.01.csv",
            "Data/Konsentra/TransformedData_Data.csv"]

# Set probabilities and time range
time_range = collect(range(6*60,23*60))

# Shifts for vehicles 
shifts = Dict(
    "Morning"    => Dict("TimeWindow" => [6*60, 12*60], "cost" => 2.0, "nVehicles" => 0, "y" => []),
    "Noon"       => Dict("TimeWindow" => [10*60, 16*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Afternoon"  => Dict("TimeWindow" => [14*60, 20*60], "cost" => 3.0, "nVehicles" => 0, "y" => []),
    "Evening"    => Dict("TimeWindow" => [18*60, 24*60], "cost" => 4.0, "nVehicles" => 0, "y" => [])
)

# Smooting factors for KDE 
bandwidth_factor_time = 1.5 
bandwidth_factor_location = 1.25

location_matrix, requestTimePickUp, requestTimeDropOff, newDataList, df_list, average_demand_per_hour, probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff, probabilities_location, density_grid, x_range, y_range,requests, distanceDriven = generateDataSetsAndvehicles(nRequest,nData,shifts,oldDataList,bandwidth_factor_time,bandwidth_factor_location)
#plotDemandAndShifts(average_demand_per_hour,shifts)

prefix = "Base Data"
heatMapBase, pickUpTimeHistBase, dropOffTimeHistBase, requestTimeBase, distanceDrivenBase = plotDataSets(x_range,y_range,density_grid,location_matrix,requestTimePickUp,requestTimeDropOff,probabilities_pickUpTime,probabilities_dropOffTime,serviceWindow,prefix,distanceDriven)

#=================================================#
# Generate time and distance matrices  
#================================================#
for i in 1:nData
    println("n = ",nRequest," i = ",i)
    requestFile = string("Data/Konsentra/",nRequest,"/GeneratedRequests_",nRequest,"_",i,".csv")
    vehicleFile = string("Data/Konsentra/",nRequest,"/Vehicles_",nRequest,".csv")
    dataName = string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",i)
    
    getTimeDistanceMatrix(requestFile, vehicleFile, dataName)
end


#================================================#
# Plot new data
#================================================#
prefix_new = "Gen. Data"

# Generate plot for each new data set 
for (idx,file) in enumerate(newDataList)
    location_matrix_new, requestTimePickUp_new, requestTimeDropOff_new, _, distanceDriven_new = getOldData([file];checkUnique=false)
    probabilities_pickUpTime_new, probabilities_dropOffTime_new, density_pickUp_new, density_dropOff_new = getRequestTimeDistribution(requestTimePickUp_new, requestTimeDropOff_new, time_range)
    probabilities_location_new, density_grid_new,x_range_new,y_range_new = getLocationDistribution(location_matrix_new)
    probabilities_distance_new, density_distance_new, distance_range_new = getDistanceDistribution(distanceDriven_new)

    # Plot data 
    heatMapGen, pickUpTimeHistGen, dropOffTimeHistGen, requestTimeGen, distanceDrivenGen = plotDataSets(x_range_new,y_range_new,density_grid_new,location_matrix_new,requestTimePickUp_new,requestTimeDropOff_new,probabilities_pickUpTime_new,probabilities_dropOffTime_new,serviceWindow,prefix_new,distanceDriven_new)

    p = plot(
        heatMapBase, heatMapGen, pickUpTimeHistBase, pickUpTimeHistGen,
        dropOffTimeHistBase, dropOffTimeHistGen, requestTimeBase, requestTimeGen,distanceDrivenBase, distanceDrivenGen,
        layout=(5,2), size=(2000,1500),
        plot_title="No. generated requests = " * string(nRequest),
        bottom_margin=5mm,
        left_margin=12mm, 
        top_margin=5mm,
        right_margin=5mm
    )
    display(p)
    savefig(p, string("Plots/DataGeneration/Plot_",nRequest,"_",idx,".svg"))

    # Plot gant chart 
    requestFile = file
    vehiclesFile = string("Data/Konsentra/",nRequest,"/Vehicles_",nRequest,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",idx,"_distance.txt")
    timeMatrixFile =  string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",idx,"_time.txt")
    scenarioName = "No. requests = " * string(nRequest)

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    p2 = createGantChartOfRequestsAndVehicles(scenario.vehicles, scenario.requests, [],scenarioName)
    display(p2)
    savefig(p2, string("Plots/DataGeneration/GantChart_",nRequest,"_",idx,".svg"))

end
