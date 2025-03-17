using JuMP
using HiGHS
using CSV
using DataFrames
using Plots
using Random

# --------
# Constants
# --------
global maxRideTimeRatio = 1
global Gamma = 0.5
global nWalking = 4

# ------
# Define possible shifts
# ------
shiftTypes = ["Morning", "Noon", "Afternoon", "Evening"]
shifts = Dict(
    "Morning"    => Dict("TimeWindow" => [6*60, 10*60], "cost" => 2.0, "nVehicles" => 0, "y" => []),
    "Noon"       => Dict("TimeWindow" => [9*60, 14*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Afternoon"  => Dict("TimeWindow" => [13*60, 19*60], "cost" => 3.0, "nVehicles" => 0, "y" => []),
    "Evening"    => Dict("TimeWindow" => [18*60, 24*60], "cost" => 4.0, "nVehicles" => 0, "y" => [])
)

# ------
# Data
# ------
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]

# ------
# Open and load data
# ------
df_list = []
sheet_names = []
for sheet in vcat(sheets_5days, sheets_data)
    df = CSV.read("Data/Konsentra/TransformedData_$sheet.csv", DataFrame)
    push!(df_list, df)
    push!(sheet_names, sheet)
end


# ------
# Save all Locations
# ------
function saveLocations(df_list)
    locationList = []
    for df in df_list
        for i in 1:nrow(df)
            latitude = df[i, :pickup_latitude]
            longitude = df[i, :pickup_longitude]
            push!(locationList, (latitude, longitude))
        end
    end
    return locationList
end

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
function generateNumberOfVehiclesKonsentra!(D, shifts)
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
    @constraint(model, [t in T], sum(x[i] * shifts[shift_names[i]]["y"][t] for i in I) >= Gamma * D[t])

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
# Plot demand and shifts
# ------
function plotDemandAndShifts(average_demand_per_hour, shifts)
    hours = 1:24  # X-axis

    # Create bar plot for demand
    bar_plot = bar(hours, average_demand_per_hour, label="Avg Demand", xlabel="Hour", ylabel="Requests",
                   title="Average Demand & Shift Coverage", legend=:topleft, alpha=0.6, color=:blue)

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

# ------
# Generate vehicles to CSV
# ------
function generateVehiclesKonsentra(shifts, locations)
    vehicles = DataFrame(id=Int[], start_of_availability=Int[], end_of_availability=Int[], 
                         maximum_ride_time=Int[], 
                         capacity_walking=Int[], depot_latitude=Float64[], depot_longitude=Float64[])

    id = 0
    for (shift, data) in shifts
        for _ in 1:data["nVehicles"]
            id += 1
            location = rand(locations)
            push!(vehicles, [id, data["TimeWindow"][1], data["TimeWindow"][2],
                             Int(floor((data["TimeWindow"][2] - data["TimeWindow"][1]) * maxRideTimeRatio / 60)), nWalking, location[1], location[2]])
        end
    end

    # Write to CSV
    CSV.write("Data/Konsentra/Vehicles_$Gamma.csv", vehicles)
end

# ------
# Update distance and time matrix
# ------



# ------
# Main  
# ------
computeShiftCoverage!(shifts)
average_demand_per_hour = generateAverageDemandPerHour(df_list)
generateNumberOfVehiclesKonsentra!(average_demand_per_hour, shifts)
plotDemandAndShifts(average_demand_per_hour, shifts)
locations = saveLocations(df_list)
generateVehiclesKonsentra(shifts, locations)
