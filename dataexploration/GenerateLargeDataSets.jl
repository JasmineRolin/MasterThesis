using CSV, DataFrames
using Plots
using KernelDensity, Statistics
using Random
using StatsBase
using domain, utils
using Plots.PlotMeasures

include("TransformKonsentraData.jl")
include("GenerateLargeVehiclesKonsentra.jl")
include("MakeAndSaveDistanceAndTimeMatrix.jl")

global DoD = 0.4 # Degree of dynamism
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global callBuffer = 2*60 # 2 hours buffer
global nData = 10
global nRequest = 500 


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
    return location_matrix, requestTimePickUp, requestTimeDropOff, requests
end



#==
# Function to get new locations from a kernel density estimate (KDE)
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


function generateDataSets(nRequest,nData,probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range)
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


#==
# Generate data sets and vehicles
==#
function generateDataSetsAndvehicles(nRequest,nData,shifts,oldDataList,bandwidth_factor_time,bandwidth_factor_location)
    # Load your old data locations and time
    location_matrix, requestTimePickUp, requestTimeDropOff,requests = getOldData(oldDataList)

    # Find time and location distributions
    probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff = getRequestTimeDistribution(requestTimePickUp, requestTimeDropOff, time_range,bandwidth_factor=bandwidth_factor_time)
    probabilities_location, density_grid, x_range, y_range = getLocationDistribution(location_matrix;bandwidth_factor = bandwidth_factor_location)

    # Generate request data 
    newDataList, df_list = generateDataSets(nRequest,nData,probabilities_pickUpTime, probabilities_dropOffTime, probabilities_location, time_range, x_range, y_range)

    # Generate vehicles 
    average_demand_per_hour = generateVehicles(shifts,df_list, probabilities_location, x_range, y_range)

    return location_matrix, requestTimePickUp, requestTimeDropOff, newDataList, df_list, average_demand_per_hour, probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff, probabilities_location, density_grid, x_range, y_range, requests
end

#==
# Create plots 
==#
function plotDataSets(x_range,y_range,density_grid,location_matrix,requestTimePickUp,requestTimeDropOff,probabilities_pickUpTime,probabilities_dropOffTime,serviceWindow,prefix::String)
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

    return p1,p2,p3,p4 
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

location_matrix, requestTimePickUp, requestTimeDropOff, newDataList, df_list, average_demand_per_hour, probabilities_pickUpTime, probabilities_dropOffTime, density_pickUp, density_dropOff, probabilities_location, density_grid, x_range, y_range,requests = generateDataSetsAndvehicles(nRequest,nData,shifts,oldDataList,bandwidth_factor_time,bandwidth_factor_location)
#plotDemandAndShifts(average_demand_per_hour,shifts)

prefix = "Base Data"
heatMapBase, pickUpTimeHistBase, dropOffTimeHistBase, requestTimeBase = plotDataSets(x_range,y_range,density_grid,location_matrix,requestTimePickUp,requestTimeDropOff,probabilities_pickUpTime,probabilities_dropOffTime,serviceWindow,prefix)

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
    location_matrix_new, requestTimePickUp_new, requestTimeDropOff_new = getOldData([file];checkUnique=false)
    probabilities_pickUpTime_new, probabilities_dropOffTime_new, density_pickUp_new, density_dropOff_new = getRequestTimeDistribution(requestTimePickUp_new, requestTimeDropOff_new, time_range)
    probabilities_location_new, density_grid_new,x_range_new,y_range_new = getLocationDistribution(location_matrix_new)

    # Plot data 
    heatMapGen, pickUpTimeHistGen, dropOffTimeHistGen, requestTimeGen = plotDataSets(x_range_new,y_range_new,density_grid_new,location_matrix_new,requestTimePickUp_new,requestTimeDropOff_new,probabilities_pickUpTime_new,probabilities_dropOffTime_new,serviceWindow,prefix_new)

    p = plot(
        heatMapBase, heatMapGen, pickUpTimeHistBase, pickUpTimeHistGen,
        dropOffTimeHistBase, dropOffTimeHistGen, requestTimeBase, requestTimeGen,
        layout=(4,2), size=(2000,1500),
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
