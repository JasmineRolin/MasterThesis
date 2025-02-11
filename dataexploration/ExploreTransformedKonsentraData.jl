
using DataFrames, CSV, Plots

# Data
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]


# ------
# Plot grid of histograms for call time
# ------
function plotHistogramsCallTime(df_list)
    # Create an array to store the plots
    plots = []

    for df in df_list
        # Create a histogram for call time and append to plots list
        p = histogram(df[!,:call_time]/60, bins=24, title="Call Time Histogram", xlabel="Call Time (hours)", ylabel="Frequency")
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(3, 2), size=(1000, 1500))
end

# ------
# Plot grid of histograms for request time
# ------
function plotHistogramsRequestTime(df_list)
    # Create an array to store the plots
    plots = []

    for df in df_list
        # Create a histogram for call time and append to plots list
        p = histogram(df[!,:request_time]/60, bins=24, title="Request Time Histogram", xlabel="Request Time (hours)", ylabel="Frequency")
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(3, 2), size=(1000, 1500))
end

# ------
# Plot gant chart of time between request time and call time for each request 
# ------
function plotGanttChart(df_list)
    plots = []

    for df in df_list
        # Ensure data has valid columns
        dfsorted = sort(df, [:request_time])
        dfsorted.duration = dfsorted[!,:request_time] .- dfsorted[!,:call_time]
        
        # Create rectangles for each activity
        rect(w, h, x, y) = Shape(x .+ [0, w, w, 0], y .+ [0, 0, h, h])
        rectangles = [rect(t[1], 1, t[2], t[3]) for t in zip(dfsorted.duration, dfsorted[!,:call_time], 1:nrow(dfsorted))]

        # Get every 5th label for yticks
        yticks_labels = string.(1:nrow(dfsorted))
        yticks_labels = yticks_labels[1:5:nrow(dfsorted)]  # Select every 5th label
        yticks_pos = 1:5:nrow(dfsorted)  # Corresponding positions for every 5th label

        # Plot Gantt chart
        p = plot(
            rectangles,
            c=:blue,
            yticks=(yticks_pos, yticks_labels),
            xlabel="Time (minutes)",
            title="Gantt Chart: Call Time to Request Time",
            legend=false
        )
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(length(df_list), 2), size=(1000, 1500))
end
# ------
# Plot Geographical data
# ------
function plotGeographicalData(df_list)
    # Create an array to store the plots
    plots = []

    # All requests
    for df in df_list
        # Create a scatter plot for geographical data
        p = scatter(df[!,:pickup_longitude], df[!,:pickup_latitude], label="Pickup", color=:blue, xlabel="Longitude", ylabel="Latitude", title="Pickup and Dropoff Locations")
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
display(plotHistogramsCallTime(df_list))
display(plotHistogramsRequestTime(df_list))
display(plotGeographicalData(df_list))
display(plotGanttChart(df_list))
println(getKeyNumbers(df_list, sheet_names))