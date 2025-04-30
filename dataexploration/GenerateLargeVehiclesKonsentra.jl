using JuMP
using HiGHS
using CSV
using DataFrames
using Plots
using Random


# ------
# Generate average demand per hour
# ------
function generateAverageDemandPerHour(df_list)
    average_demand_per_hour = zeros(24)
    demand_per_hour = zeros(24)

    for df in df_list
        for i in 1:nrow(df)
            request_time = df[i, :request_time]
            hour = Int(floor(request_time / 60)) + 1
            demand_per_hour[hour] += 1
        end
    end

    average_demand_per_hour .= demand_per_hour ./ length(df_list)
    return average_demand_per_hour
end

# ------
# Compute shift coverage & store in shifts dictionary
# ------
function computeShiftCoverage!(shifts)
    T = 24  # Hours in a day
    for (shift, data) in shifts
        y = zeros(Int, T)
        start_time, end_time = data["TimeWindow"]
        start_hour = Int(floor(start_time / 60)) + 1
        end_hour = Int(floor(end_time / 60))

        for t in start_hour:end_hour
            y[t] = 1
        end
        shifts[shift]["y"] = y
    end
end

# ------
# Make MILP model to generate number of vehicles
# ------
function generateNumberOfVehiclesKonsentra!(average_demand_per_hour, shifts,Gamma)
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    shift_names = collect(keys(shifts))
    nShifts = length(shift_names)
    I = 1:nShifts
    T = 1:24

    # Variables
    @variable(model, x[i in I] >= 0, Int)  # Number of each shift

    # Objective
    @objective(model, Min, sum(x[i] * shifts[shift_names[i]]["cost"] for i in I))

    # Constraints
    @constraint(model, [t in T], sum(x[i] * shifts[shift_names[i]]["y"][t] for i in I) >= Gamma * average_demand_per_hour[t])

    # Optimize model
    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL
        println("Solver terminated with status: ", termination_status(model))
        error("No optimal solution found.")
    end

    # Store results in shifts dictionary
    for i in I
        shifts[shift_names[i]]["nVehicles"] = value(x[i])
    end
end

# ------
# Generate vehicles to CSV
# ------
function generateVehiclesKonsentra(shifts,vehicleCapacity, locations,vehicle_file::String)
    vehicles = DataFrame(id=Int[], start_of_availability=Int[], end_of_availability=Int[], 
                         maximum_ride_time=Int[], 
                         capacity_walking=Int[], depot_latitude=Float64[], depot_longitude=Float64[])

    id = 0
    for (shift, data) in shifts
        for _ in 1:data["nVehicles"]
            id += 1
            location = locations[id]
            push!(vehicles, [id, data["TimeWindow"][1], data["TimeWindow"][2],
                             Int(floor((data["TimeWindow"][2] - data["TimeWindow"][1]) / 60)), vehicleCapacity, location[1], location[2]])
        end
    end

    # Write to CSV
    CSV.write(vehicle_file, vehicles)
end

function load_request_data(nRequests::Int,nData::Int)
    df_list = []

    for i in 1:nData
        filename = "Data/Konsentra/"*string(nRequests)*"/GeneratedRequests_"*string(nRequests)*"_"*string(i)*".csv"
        if isfile(filename)
            df = CSV.read(filename, DataFrame)
            push!(df_list, df)
        else
            @warn "File not found: $filename"
        end
    end

    return df_list
end

#==
# Method to generate vehicles for generated data 
==#
function generateVehicles(shifts,df_list, probabilities_location, x_range, y_range,Gamma,vehicleCapacity,nRequest,max_lat,min_lat,max_long,min_long,nRows,nCols)
    # Find possible depots locations 
    grid_centers = findGridCenters(max_lat,min_lat,max_long,min_long,nRows,nCols)[3]

    # Compute shift coverage 
    computeShiftCoverage!(shifts)
    average_demand_per_hour = generateAverageDemandPerHour(df_list)

    # Generate number of vehicles
    generateNumberOfVehiclesKonsentra!(average_demand_per_hour, shifts,Gamma)

    # Determine depot locations 
    locations = []
    total_nVehicles = sum(shift["nVehicles"] for shift in values(shifts))
    for i in 1:total_nVehicles
        original_loc = getNewLocations(probabilities_location, x_range, y_range)
        closest_center = findClosestGridCenter(original_loc, grid_centers)
        push!(locations, closest_center)
    end

    # Generate vehicles 
    generateVehiclesKonsentra(shifts,vehicleCapacity, locations,"Data/Konsentra/"*string(nRequest)*"/Vehicles_"*string(nRequest)*"_"*string(Gamma)*".csv")

    return average_demand_per_hour
end

#==
# Method to sample new locati$ns 
==#
function getNewLocations(probabilities::Vector{Float64},x_range::Vector{Float64}, y_range::Vector{Float64})
    # Sample locations based on probabilities
    sampled_idx = sample(1:length(probabilities), Weights(probabilities))
    sampled_location = (y_range[(sampled_idx - 1) % length(y_range) + 1],x_range[(sampled_idx - 1) ÷ length(y_range) + 1])

    return sampled_location
end



#==
# Method to find grid centers 
==#
function findGridCenters(max_lat, min_lat, max_long, min_long, nRows, nCols)
    # Compute grid spacing
    lat_step = (max_lat - min_lat) / nRows
    long_step = (max_long - min_long) / nCols

    # Generate grid cell centers
    grid_centers_lat = [min_lat + (i + 0.5) * lat_step for i in 0:nRows-1]
    grid_centers_long = [min_long + (j + 0.5) * long_step for j in 0:nCols-1]
    grid_centers = [(lat, lon) for lat in grid_centers_lat, lon in grid_centers_long]

    return lat_step, long_step, grid_centers
end

#==
# Method to find the closest grid center to a given location    
==#
function findClosestGridCenter(loc, grid_centers)
    lat, lon = loc
    closest_center = nothing
    min_dist = Inf

    for (clat, clon) in grid_centers
        dist = haversine_distance(lat, lon, clat, clon)[1]
        if dist < min_dist
            min_dist = dist
            closest_center = (clat, clon)
        end
    end
 
    return closest_center
end


#==
# Plot demand and shifts
==#
function plotDemandAndShifts(average_demand_per_hour, shifts,gamma)
    hours = 1:24  # X-axis

    # Create bar plot for demand
    bar_plot = bar(hours, average_demand_per_hour, label="Avg Demand", xlabel="Hour", ylabel="Requests",
                   title=string("Average Demand & Shift Coverage, gamma: ",gamma), legend=:topleft, alpha=0.6, color=:blue,size=(900,500))

    # Overlay shifts as horizontal lines
    for (shift, data) in shifts
        start_hour = Int(floor(data["TimeWindow"][1] / 60)) + 1
        end_hour = Int(floor(data["TimeWindow"][2] / 60))

        # Plot shift as a horizontal line
        plot!(hours[start_hour:end_hour], fill(data["nVehicles"], end_hour - start_hour + 1),
              label=shift, lw=4, alpha=0.8)
    end

    display(bar_plot)
end



# Plot request locations and vehicles 
function plotRequestsAndVehicles(n,nData,gamma,max_lat,min_lat,max_long,min_long,NUM_ROWS,nCols,grid_centers,lat_step, long_step)
    vehiclesFile = string("Data/Konsentra/", n, "/Vehicles_",n,"_", gamma, ".csv")
    vehiclesDf = CSV.read(vehiclesFile, DataFrame)

    for i in 1:nData
        fileName = string("Data/Konsentra/", n, "/GeneratedRequests_", n, "_", i, ".csv")
        requestsDf = CSV.read(fileName, DataFrame)

        p = plot(size = (1500, 1000))
        scatter!(p, requestsDf.pickup_longitude, requestsDf.pickup_latitude, label = "Pick-up", color = :blue, markersize = 3)
        scatter!(p, requestsDf.dropoff_longitude, requestsDf.dropoff_latitude, label = "Drop-off", color = :red, markersize = 3)
        scatter!(p, vehiclesDf.depot_longitude, vehiclesDf.depot_latitude, label = "Vehicles", color = :black, markersize = 5,marker=:square)

        offset = 0.001
        for (idx, row) in enumerate(eachrow(requestsDf))
            annotate!(p, (row.pickup_longitude, row.pickup_latitude-offset, text("PU$idx", :blue, 8,:top)))
            annotate!(p, (row.dropoff_longitude, row.dropoff_latitude-offset, text("DO$idx", :red, 8,:top)))
        end

        coord_counts = Dict{Tuple{Float64, Float64}, Int}()
        for (idx, row) in enumerate(eachrow(vehiclesDf))
            pos = (row.depot_longitude, row.depot_latitude)
            count = get!(coord_counts, pos, 0)
            y_offset = 0.01 * count  # tune this offset as needed
            annotate!(p, (row.depot_longitude, row.depot_latitude + offset + y_offset, text("D$idx", :black, 8,:bottom)))
            coord_counts[pos] += 1
        end
        
        # Bounding box
        lons = [min_long, max_long, max_long, min_long, min_long]
        lats = [min_lat, min_lat, max_lat, max_lat, min_lat]
        plot!(p, lons, lats, label = "", color = :green, linewidth = 2)

        # Grid lines
        for lat in [min_lat + i * lat_step for i in 0:NUM_ROWS]
            plot!(p, [min_long, max_long], [lat, lat], color = :gray, linestyle = :dash, label = "")
        end
        for lon in [min_long + j * long_step for j in 0:nCols]
            plot!(p, [lon, lon], [min_lat, max_lat], color = :gray, linestyle = :dash, label = "")
        end

        # Plot grid cell centers
        for (lat,lon) in grid_centers
            scatter!(p, [lon], [lat], color = :gray, marker = (:cross, 4), label = "")
        end

        display(p)
        savefig(p, string("plots/DataGeneration/RequestsAndVehicles_",gamma,"_",n,"_",i,".svg"))
    end
end