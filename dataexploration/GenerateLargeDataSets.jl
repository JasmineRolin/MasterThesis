using CSV, DataFrames
using Plots
using KernelDensity, Statistics
using Random
using StatsBase
using domain, utils
using Plots.PlotMeasures


#==
# Method to load simulation data 
==#
function load_simulation_data(input_dir::String)
    location_df = CSV.read(joinpath(input_dir, "location_matrix.csv"), DataFrame)
    location_matrix = hcat(Float64.(location_df.longitude), Float64.(location_df.latitude))

    requestTime = Int.(CSV.read(joinpath(input_dir, "request_time.csv"), DataFrame).time)

    requests_df = CSV.read(joinpath(input_dir, "requests.csv"), DataFrame)
    requests = [(r.request_type, r.pickup_latitude, r.pickup_longitude, r.dropoff_latitude, r.dropoff_longitude)
                for r in eachrow(requests_df)]

    distanceDriven = Float64.(CSV.read(joinpath(input_dir, "distance_driven.csv"), DataFrame).distance)
    probabilities_distance = Float64.(CSV.read(joinpath(input_dir, "distance_distribution.csv"), DataFrame).probability)
    density_distance = Float64.(CSV.read(joinpath(input_dir, "density_distance.csv"), DataFrame).density)
    distance_range = Float64.(CSV.read(joinpath(input_dir, "distance_range.csv"), DataFrame).distance)

    probabilities_time = Float64.(CSV.read(joinpath(input_dir, "time_distribution.csv"), DataFrame).probability)
    probabilities_offline = collect(Float64.(CSV.read(joinpath(input_dir, "offline_time_distribution.csv"), DataFrame).probability))
    probabilities_online = collect(Float64.(CSV.read(joinpath(input_dir, "online_time_distribution.csv"), DataFrame).probability))

    x_range = Float64.(CSV.read(joinpath(input_dir, "x_range.csv"), DataFrame).x)
    y_range = Float64.(CSV.read(joinpath(input_dir, "y_range.csv"), DataFrame).y)

    density_flat = Float64.(CSV.read(joinpath(input_dir, "density_grid.csv"), DataFrame).density)
    density_grid = reshape(density_flat, length(y_range), length(x_range))

    # Replace missing values with 0.0 
    # TODO: why are there missing values ? 
    probabilities_location = coalesce.(Float64.(CSV.read(joinpath(input_dir, "probabilities_location.csv"), DataFrame).probability), 0.0)

    println("✅ All simulation data loaded from $input_dir")

    return (
        probabilities_time,
        probabilities_offline,
        probabilities_online,
        probabilities_location,
        density_grid,
        x_range,
        y_range,
        probabilities_distance,
        density_distance,
        distance_range,
        location_matrix,
        requestTime,
        requests,
        distanceDriven,
    )
end

#==
# Generate data sets and vehicles
==#
function generateDataSets(nRequest,DoD,nData,time_range,max_lat, min_lat, max_long, min_long,only_pickup,limitEarlyCallTime,earliestBuffer)
    # Load simulation data
    probabilities_time,
    probabilities_offline,
    probabilities_online,
        probabilities_location,
        density_grid,
        x_range,
        y_range,
        probabilities_distance,
        density_distance,
        distance_range,
        location_matrix,
        requestTime,
        requests,
        distanceDriven= load_simulation_data("Data/Simulation data/")

    # Generate request data 
    newDataList, df_list = generateData(nRequest,DoD,nData, probabilities_offline, probabilities_online, probabilities_location, time_range, x_range, y_range,distance_range,probabilities_distance,max_lat, min_lat, max_long, min_long,only_pickup,limitEarlyCallTime,earliestBuffer)

    return location_matrix, requestTime, newDataList, df_list, probabilities_time,probabilities_offline,probabilities_online,probabilities_location, density_grid, x_range, y_range, requests, distanceDriven
end


#==
# Generate data sets
==#
function generateData(nRequest,DoD,nData,probabilities_offline, probabilities_online, probabilities_location, time_range, x_range, y_range,distance_range::Vector{Float64},probabilities_distance::Vector{Float64},max_lat, min_lat, max_long, min_long,only_pickup,limitEarlyCallTime,earliestBuffer)
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
                results = makeRequests(nRequest,DoD, probabilities_offline, probabilities_online, probabilities_location, time_range, x_range, y_range, output_file,distance_range,probabilities_distance,max_lat, min_lat, max_long, min_long,only_pickup,limitEarlyCallTime,earliestBuffer)
                
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

#==
# Make request
==#
function makeRequests(nSample::Int, DoD::Float64, probabilities_offline::Vector{Float64}, probabilities_online::Vector{Float64}, probabilities_location::Vector{Float64}, time_range::Vector{Int}, x_range::Vector{Float64}, y_range::Vector{Float64}, output_file::String,distance_range::Vector{Float64},probabilities_distance::Vector{Float64},max_lat, min_lat, max_long, min_long,only_pickup,limitEarlyCallTime,earliestBuffer)
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


    nOffline = ceil(Int, nSample * (1-DoD))
    nOnline = nSample - nOffline
    preKnown = falses(nOffline + nOnline)

    # Generate offline requests 
    for i in 1:nOffline
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance,max_lat, min_lat, max_long, min_long)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]

        # Determine type of request
        if only_pickup || rand() < 0.5
            requestType = 0  # pick-up request

            sampled_indices = sample(1:length(probabilities_offline), Weights(probabilities_offline), 1)
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

            sampled_indices = sample(1:nTimes, Weights(probabilities_offline[indices]), 1)
            sampledTimeDrop = time_range[indices][sampled_indices]
            requestTime = ceil(sampledTimeDrop[1])
        end

        # Append results for the request
        preKnown[i] = true
        push!(results, (i, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, requestType, requestTime,"WALKING",0,0))

    end

    # Generate online requests 
    for i in 1:nOnline
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance,max_lat, min_lat, max_long, min_long)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]

        # Determine type of request
        if only_pickup || rand() < 0.5
            requestType = 0  # pick-up request

            sampled_indices = sample(1:length(probabilities_online), Weights(probabilities_online), 1)
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

            sampled_indices = sample(1:nTimes, Weights(probabilities_online[indices]), 1)
            sampledTimeDrop = time_range[indices][sampled_indices]
            requestTime = ceil(sampledTimeDrop[1])
        end

        # Append results for the request
        push!(results, (i+nOffline, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, requestType, requestTime,"WALKING",0,0))

    end

    # Determine call time
    if limitEarlyCallTime
        earlyCallTime(results, serviceWindow, earliestBuffer, callBuffer, preKnown)
    else 
        callTime(results, serviceWindow, callBuffer, preKnown)
    end
    


    # Write results to CSV
    mkpath(dirname(output_file))
    CSV.write(output_file, results)

    return results
end

function getNewLocations(probabilities::Vector{Float64},x_range::Vector{Float64},y_range::Vector{Float64}, distance_range::Vector{Float64},probabilities_distance::Vector{Float64},max_lat, min_lat, max_long, min_long; tolerance_km::Float64 = 1.0)
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
    dropoff_x, dropoff_y = find_dropoff((pickup_x, pickup_y), grid_coords, sampled_distance, probabilities; tolerance_km=tolerance_km)

    # Make sure location is in grid 
    if pickup_x < min_long 
        pickup_x = min_long
    elseif pickup_x > max_long
        pickup_x = max_long
    end
    if pickup_y < min_lat 
        pickup_y = min_lat
    elseif pickup_y > max_lat
        pickup_y = max_lat
    end

    if dropoff_x < min_long 
        dropoff_x = min_long
    elseif dropoff_x > max_long
        dropoff_x = max_long
    end
    if dropoff_y < min_lat 
        dropoff_y = min_lat
    elseif dropoff_y > max_lat
        dropoff_y = max_lat
    end

    return [(pickup_x, pickup_y), (dropoff_x, dropoff_y)]
end


#==
# Method to sample drop off location  
==#
function find_dropoff(pickup::Tuple{Float64, Float64}, grid_coords::Vector{Tuple{Float64, Float64}},distance_sample::Float64,probabilities::Vector{Float64};tolerance_km::Float64 = 1.0)

    # Compute distances from pickup to all grid coordinates
    distances = [haversine_distance(pickup[2], pickup[1], lat, lon)[1] for (lon, lat) in grid_coords]

    # Find grid indices within tolerance
    candidate_idxs = findall(abs.(distances .- distance_sample) .<= tolerance_km)

    # Remove pickup location itself from candidates
    candidate_idxs = filter(i -> grid_coords[i] != pickup, candidate_idxs)

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


#==========================================================#
# Plots 
#==========================================================#
#==
# Create plots 
==#
function plotDataSets(x_range,y_range,density_grid,location_matrix,requestTime_offline,requestTime_online,probabilities_offline,probabilities_online,probabilities_all,serviceWindow,prefix::String,distanceDriven)
    min_x = 5
    max_x = 24

    # Visualize results 
    p1 = heatmap(x_range, y_range, -density_grid, xlabel="Longitude", ylabel="Latitude", title=prefix*" Location Density Map",c = :RdYlBu_9,colorbar=false)
    scatter!(location_matrix[:,1], location_matrix[:,2], marker=:circle, label="Locations", color=:blue,markersize=3)

    # Plot request time distribution offline 
    requestTime_hours_offline = requestTime_offline ./ 60
    time_range_hours = time_range ./ 60
    probabilities_scaled_offline = probabilities_offline .* 60

    if requestTime_hours_offline == []
        p2 = plot()
        title!(prefix*" Offline Request Time Distribution")
        xlabel!("Time (Hours)")
        ylabel!("Probability Density")
    else        
        p2 = histogram(requestTime_hours_offline, normalize=:pdf, label="", color=:blue, bins=24)
        plot!(time_range_hours, probabilities_scaled_offline, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red)
        vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
        vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
        title!(prefix*" Offline Request Time Distribution")
        xlabel!("Time (Hours)")
        ylabel!("Probability Density")
        xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
        plot!(xticks=xtick_values)
    end

    # Plot request time distribution online 
    requestTime_hours_online = requestTime_online ./ 60
    time_range_hours = time_range ./ 60
    probabilities_scaled_online = probabilities_online .* 60

    p3 = histogram(requestTime_hours_online, normalize=:pdf, label="", color=:blue, bins = 24)
    plot!(time_range_hours, probabilities_scaled_online, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Online Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    # Plot histogram of all requests
    requestTime = vcat(requestTime_hours_offline,requestTime_hours_online)
    probabilities_scaled_all = probabilities_all .* 60
    p4 = histogram(requestTime, normalize=:pdf, label="", color=:blue,bins=24, size = (900,500))
    plot!(time_range_hours, probabilities_scaled_all, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    p5 = histogram(distanceDriven, normalize=:pdf, label="", color=:blue,bins=24)
    title!(prefix*" Distance Driven Distribution")
    xlabel!("Driven distance")
    ylabel!("Probability Density")


    return p1,p2,p3,p4,p5
end


function plotDataSetsOriginal(x_range,y_range,density_grid,location_matrix,requestTime,probabilities_time,probabilities_online,probabilities_offline,serviceWindow,prefix::String,distanceDriven)
    min_x = 5
    max_x = 24

    # Visualize results 
    p1 = heatmap(x_range, y_range, -density_grid, xlabel="Longitude", ylabel="Latitude", title=prefix*" Location Density Map",c = :RdYlBu_9,colorbar=false)
    scatter!(location_matrix[:,1], location_matrix[:,2], marker=:circle, label="Locations", color=:blue,markersize=3)

    # Plot offline request time distribution 
    requestTime_hours = requestTime ./ 60
    time_range_hours = time_range ./ 60
    probabilities_scaled_offline = probabilities_offline .* 60

    p2 = histogram(requestTime_hours, normalize=:pdf, label="", color=:blue,bins=24)
    plot!(time_range_hours, probabilities_scaled_offline, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red,bins=19)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Offline Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    # Plot online request time distribution 
    requestTime_hours = requestTime ./ 60
    time_range_hours = time_range ./ 60
    probabilities_scaled_online = probabilities_online .* 60

    p3 = histogram(requestTime_hours, normalize=:pdf, label="", color=:blue,bins=24)
    plot!(time_range_hours, probabilities_scaled_online, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red,bins=19)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Online Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    # Plot all request time distribution 
    requestTime_hours = requestTime ./ 60
    time_range_hours = time_range ./ 60
    probabilities_scaled = probabilities_time .* 60

    p4 = histogram(requestTime_hours, normalize=:pdf, label="", color=:blue, bins=24)
    plot!(time_range_hours, probabilities_scaled, label="Probability Distribution", linewidth=4, linestyle=:solid, color=:red,bins=19)
    vline!([serviceWindow[1]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    vline!([serviceWindow[2]/60], linestyle=:dash, color=:grey, linewidth=2, label="")
    title!(prefix*" Request Time Distribution")
    xlabel!("Time (Hours)")
    ylabel!("Probability Density")
    xtick_values = range(min_x, max_x, step=1)  # Adjust length for more ticks
    plot!(xticks=xtick_values)

    p5 = histogram(distanceDriven, normalize=:pdf, label="", color=:blue,bins=24)
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



function createAndSavePlotsGeneratedData(newDataList,nRequest,x_range,y_range,density_grid,location_matrix,requestTime,probabilities_time,probabilities_offline,probabilities_online,serviceWindow,distanceDriven)
    # Create plots for base data 
    prefix = "Base Data"
    heatMapBase, requestTimeOfflineBase, requestTimeOnlineBase, requestTimeBase, distanceDrivenBase = plotDataSetsOriginal(x_range,y_range,density_grid,location_matrix,requestTime,probabilities_time,probabilities_online,probabilities_offline,serviceWindow,prefix,distanceDriven)


    prefix_new = "Gen. Data"

    # Generate plot for each new data set 
    for (idx,file) in enumerate(newDataList)
        location_matrix_new, requestTime_offline_new,requestTime_online_new, _, distanceDriven_new = getNewData([file];checkUnique=false) 
        requestTime_all_new = vcat(requestTime_offline_new,requestTime_online_new)
        probabilities_all_new, density_new = getRequestTimeDistribution(requestTime_all_new, time_range)
        probabilities_offline_new, density_new = getRequestTimeDistribution(requestTime_offline_new, time_range)
        probabilities_online_new, density_new = getRequestTimeDistribution(requestTime_online_new, time_range)
        adj_probabilities_offline_new = getOfflineRequestTimeDistribution(probabilities_offline_new, time_range)
        adj_probabilities_online_new = getOnlineRequestTimeDistribution(probabilities_online_new, time_range)
        probabilities_location_new, density_grid_new,x_range_new,y_range_new = getLocationDistribution(location_matrix_new)
        probabilities_distance_new, density_distance_new, distance_range_new = getDistanceDistribution(distanceDriven_new)

        # Plot data 
        heatMapGen, offlineTimeHistGen, onlineTimeHistGen, allTimeHistGen, distanceDrivenGen = plotDataSets(x_range_new,y_range_new,density_grid_new,location_matrix_new,requestTime_offline_new,requestTime_online_new,adj_probabilities_offline_new,adj_probabilities_online_new,probabilities_all_new,serviceWindow,prefix_new,distanceDriven_new)
        p = plot(
            heatMapBase, heatMapGen, requestTimeOfflineBase, offlineTimeHistGen, requestTimeOnlineBase, onlineTimeHistGen, requestTimeBase, allTimeHistGen, distanceDrivenBase, distanceDrivenGen,
            layout=(5,2), size=(2000,1500),
            plot_title="No. generated requests = " * string(nRequest),
            bottom_margin=5mm,
            left_margin=12mm, 
            top_margin=5mm,
            right_margin=5mm
        )
        display(p)
        savefig(p, string("plots/DataGeneration/Plot_",nRequest,"_",idx,".svg"))
    end
end

function plotAndSaveGantChart(nRequest::Int,nData::Int,gamma::Float64,limitEarlyCallTime::Bool,gridSize::Int)
    for idx in 1:nData
        # Plot gant chart 
        requestFile = string("Data/Konsentra/",nRequest,"/GeneratedRequests_",nRequest,"_",idx,".csv")
        vehiclesFile = string("Data/Konsentra/",nRequest,"/Vehicles_",nRequest,"_",gamma,".csv")

        if limitEarlyCallTime
            parametersFile = "tests/resources/ParametersShortCallTime.csv"
        else
            parametersFile = "tests/resources/Parameters.csv"
        end
   
        distanceMatrixFile = string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",gamma,"_",idx,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",gamma,"_",idx,"_time.txt")
        scenarioName = "No. requests = " * string(nRequest)
        gridFile = "Data/Konsentra/grid_$(gridSize).json"

        # Read instance 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)

        p2 = createGantChartOfRequestsAndVehicles(scenario.vehicles, scenario.requests, [],scenarioName)
        display(p2)
        savefig(p2, string("plots/DataGeneration/GantChart_",nRequest,"_",gamma,"_",idx,".svg"))
    end
end


