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
function generateNumberOfVehiclesKonsentra!(average_demand_per_hour, shifts)
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
function generateVehiclesKonsentra(shifts, locations,vehicle_file::String)
    vehicles = DataFrame(id=Int[], start_of_availability=Int[], end_of_availability=Int[], 
                         maximum_ride_time=Int[], 
                         capacity_walking=Int[], depot_latitude=Float64[], depot_longitude=Float64[])

    id = 0
    for (shift, data) in shifts
        for _ in 1:data["nVehicles"]
            id += 1
            location = locations[id]
            push!(vehicles, [id, data["TimeWindow"][1], data["TimeWindow"][2],
                             Int(floor((data["TimeWindow"][2] - data["TimeWindow"][1]) * maxRideTimeRatio / 60)), nWalking, location[2], location[1]])
        end
    end

    # Write to CSV
    CSV.write(vehicle_file, vehicles)
end

function load_request_data(nRequests::Int)
    df_list = []

    for i in 1:10
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


function generateVehicles(shifts,df_list, probabilities_location, x_range, y_range)
    computeShiftCoverage!(shifts)
    average_demand_per_hour = generateAverageDemandPerHour(df_list)

    generateNumberOfVehiclesKonsentra!(average_demand_per_hour, shifts)

    locations = []
    total_nVehicles = sum(shift["nVehicles"] for shift in values(shifts))
    for i in 1:total_nVehicles
        push!(locations,getNewLocations(probabilities_location,x_range, y_range)[1])
    end
    generateVehiclesKonsentra(shifts, locations,"Data/Konsentra/"*string(nRequest)*"/Vehicles_"*string(nRequest)*"_"*string(Gamma)*".csv")

    return average_demand_per_hour
end

function plotDemandAndShifts(average_demand_per_hour, shifts)
    hours = 1:24  # X-axis

    # Create bar plot for demand
    bar_plot = bar(hours, average_demand_per_hour, label="Avg Demand", xlabel="Hour", ylabel="Requests",
                   title="Average Demand & Shift Coverage", legend=:topleft, alpha=0.6, color=:blue,size=(900,500))

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


# --------
# Constants
# --------

global maxRideTimeRatio = 1
global Gamma = 0.9
global nWalking = 4


##################################################
# Generate vehicles
##################################################
#==
nRequest = 20 # Number of requests

# Set probabilities and time range
time_range = collect(range(6*60,23*60))

# Shifts for vehicles 
shiftTypes = ["Morning", "Noon", "Afternoon", "Evening"]
shifts = Dict(
    "Morning"    => Dict("TimeWindow" => [6*60, 12*60], "cost" => 2.0, "nVehicles" => 0, "y" => []),
    "Noon"       => Dict("TimeWindow" => [10*60, 16*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Afternoon"  => Dict("TimeWindow" => [14*60, 20*60], "cost" => 3.0, "nVehicles" => 0, "y" => []),
    "Evening"    => Dict("TimeWindow" => [18*60, 24*60], "cost" => 4.0, "nVehicles" => 0, "y" => [])
)

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

# Read data
df_list = load_request_data(nRequest)

# Generate vehicles 
average_demand_per_hour = generateVehicles(shifts,df_list, probabilities_location, x_range, y_range)
==#
