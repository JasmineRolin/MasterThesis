
using DataFrames, CSV, Plots

# Data
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]


# ------
# Plot grid of histograms for call time
# ------
function plotHistogramsCallTime(df_list,sheet_names)
    # Create an array to store the plots
    plots = []

    for (idx,df) in enumerate(df_list)
        # Create a histogram for call time and append to plots list
        p = histogram(df[!,:call_time]/60, bins=24, title=string("Call Time Histogram: ",sheet_names[idx]), xlabel="Call Time (hours)", ylabel="Frequency")
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(3, 2), size=(1000, 1500))
end

# ------
# Plot grid of histograms for request time
# ------

function plotHistogramsRequestTime(df_list, sheet_names)
    plots_pickup = []
    plots_dropoff = []

    for (idx, df) in enumerate(df_list)
        # Filter data by request type
        df_pickup = filter(row -> row.request_type == 0, df)
        df_dropoff = filter(row -> row.request_type == 1, df)

        # Create histograms for each request type
        p_pickup = histogram(df_pickup.request_time / 60, bins=24, 
                             title=string("Pickup Request Time: ", sheet_names[idx]), 
                             xlabel="Request Time (hours)", ylabel="Frequency")
        push!(plots_pickup, p_pickup)

        p_dropoff = histogram(df_dropoff.request_time / 60, bins=24, 
                              title=string("Dropoff Request Time: ", sheet_names[idx]), 
                              xlabel="Request Time (hours)", ylabel="Frequency")
        push!(plots_dropoff, p_dropoff)
    end

    # Create a layout with separate plots for Pickup and Dropoff
    plot(plots_pickup..., layout=(length(df_list), 1), size=(1000, 1500))
    #plot(plots_dropoff..., layout=(length(df_list), 1), size=(1000, 1500))
end


# ------
# Plot gant chart of time between request time and call time for each request 
# ------
function plotGanttChart(df_list, sheet_names)
    plots = []

    for (idx, df) in enumerate(df_list)
        # Ensure data has valid columns
        dfsorted = sort(df, [:request_time])

        # Determine durations
        durations = []
        for i in 1:nrow(dfsorted)
            if dfsorted[i, :request_type] == 1  # Pick up
                push!(durations, dfsorted[i, :request_time] - dfsorted[i, :call_time])
            else  # Drop off
                direct_drive_time = dfsorted[i, :direct_drive_time]
                direct_pick_up_time = dfsorted[i, :request_time] - direct_drive_time
                push!(durations, direct_pick_up_time - dfsorted[i, :call_time])
            end
        end

        dfsorted.duration = durations

        # Create rectangles with different colors based on request_type
        rect(w, h, x, y) = Shape(x .+ [0, w, w, 0], y .+ [0, 0, h, h])

        rectangles_pickup = [
            rect(t[1], 1, t[2], t[3]) 
            for t in zip(dfsorted.duration[dfsorted.request_type .== 0], 
                         dfsorted[!,:call_time][dfsorted.request_type .== 0], 
                         findall(dfsorted.request_type .== 0))
        ]

        rectangles_dropoff = [
            rect(t[1], 1, t[2], t[3]) 
            for t in zip(dfsorted.duration[dfsorted.request_type .== 1], 
                         dfsorted[!,:call_time][dfsorted.request_type .== 1], 
                         findall(dfsorted.request_type .== 1))
        ]

        # Get every 5th label for yticks
        yticks_labels = string.(1:nrow(dfsorted))
        yticks_labels = yticks_labels[1:5:nrow(dfsorted)]  # Select every 5th label
        yticks_pos = 1:5:nrow(dfsorted)  # Corresponding positions for every 5th label

        # Extract request times and corresponding y-values
        request_times = dfsorted[!,:request_time]
        y_positions = 1:nrow(dfsorted)  # Same y-values as the rectangles

        # Plot Gantt chart
        p = plot(
            yticks=(yticks_pos, yticks_labels),
            xlabel="Time (minutes)",
            title=string("Gantt Chart: Call Time to Request Time:", sheet_names[idx]),
            legend=false
        )

        # Plot different colors for different request types
        plot!(p, rectangles_pickup, c=:blue, label="Pick Up")  # Blue for Pick Up
        plot!(p, rectangles_dropoff, c=:green, label="Drop Off")  # Green for Drop Off

        # Add red dots at request times
        scatter!(p, request_times, y_positions, color=:red, markersize=4, label=false)

        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(length(df_list), 2), size=(1000, 1500))
end


# ------
# Plot Geographical data
# ------
function plotGeographicalData(df_list,sheet_names)
    # Create an array to store the plots
    plots = []

    # All requests
    for (idx,df) in enumerate(df_list)
        # Create a scatter plot for geographical data
        p = scatter(df[!,:pickup_longitude], df[!,:pickup_latitude], label="Pickup", color=:blue, xlabel="Longitude", ylabel="Latitude", title=string("Pickup and Dropoff Locations: ",sheet_names[idx]))
        scatter!(p, df[!,:dropoff_longitude], df[!,:dropoff_latitude], label="Dropoff", color=:red)
        push!(plots, p)

        # Filter out requests with request_time > 0
        df_filtered = filter(row -> row[:call_time] == 0, df)
        # Create a scatter plot for geographical data
        p = scatter(df_filtered[!,:pickup_longitude], df_filtered[!,:pickup_latitude], label="Pickup", color=:blue, xlabel="Longitude", ylabel="Latitude", title="Pickup and Dropoff Locations for the offline problem")
        scatter!(p, df_filtered[!,:dropoff_longitude], df_filtered[!,:dropoff_latitude], label="Dropoff", color=:red)
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(length(df_list), 2), size=(1000, 1500))
end

# ------
# Extract key numbers
# ------
function getKeyNumbers(df_list, sheet_names)
    # Create a DataFrame to store the key numbers
    key_numbers = DataFrame(
        sheet = sheet_names,
        n_requests = [nrow(df) for df in df_list],
        n_offline = [sum(df[!,:call_time] .== 0) for df in df_list],
        earliest_request = [minimum(df[!,:request_time]) for df in df_list],
        latest_request = [maximum(df[!,:request_time]) for df in df_list],
        earliest_call = [minimum(df[!,:call_time]) for df in df_list],
        latest_call = [maximum(df[!,:call_time]) for df in df_list],
        smallest_time_between_call_request = [minimum(df[!,:request_time] .- df[!,:call_time]) for df in df_list]
    )
    return key_numbers
end

#==
# ------
# Open and load data
# ------
df_list = []  # To store the transformed DataFrames
sheet_names = []  # To store the sheet names
for sheet in sheets_5days
    df = CSV.read("Data/Konsentra/TransformedData_$sheet.csv", DataFrame)
    push!(df_list, df)
    push!(sheet_names, sheet)
end

for sheet in sheets_data
    df = CSV.read("Data/Konsentra/TransformedData_$sheet.csv", DataFrame)
    push!(df_list, df)
    push!(sheet_names, sheet)
end

# ------
# Plots
# ------
display(plotHistogramsCallTime(df_list,sheet_names))
display(plotHistogramsRequestTime(df_list,sheet_names))
display(plotGeographicalData(df_list,sheet_names))
display(plotGanttChart(df_list,sheet_names))
#println(getKeyNumbers(df_list, sheet_names))
==#


# ------
# Open and load data
# ------
df_list = []  # To store the transformed DataFrames
sheet_names = []  # To store the sheet names
sheets = ["1","2","3","4"]
for sheet in sheets
    df = CSV.read("Data/Konsentra/100/GeneratedRequests_100_$sheet.csv", DataFrame)
    push!(df_list, df)
    push!(sheet_names, sheet)
end

# ------
# Plots
# ------
#display(plotHistogramsCallTime(df_list,sheet_names))
display(plotHistogramsRequestTime(df_list,sheet_names))
display(plotGeographicalData(df_list,sheet_names))
#display(plotGanttChart(df_list,sheet_names))
#println(getKeyNumbers(df_list, sheet_names))
