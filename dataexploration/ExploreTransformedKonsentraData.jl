
using DataFrames, CSV, Plots

# Data
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]


# ------
# Plot grid of histograms for call time
# ------
function plotHistograms(df_list)
    # Create an array to store the plots
    plots = []

    for df in df_list
        # Create a histogram for call time and append to plots list
        p = histogram(df[!,:call_time], bins=30, title="Call Time Histogram", xlabel="Call Time (minutes)", ylabel="Frequency")
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(3, 2))
end

# ------
# Plot grid of histograms for request time
# ------
function plotHistograms(df_list)
    # Create an array to store the plots
    plots = []

    for df in df_list
        # Create a histogram for call time and append to plots list
        p = histogram(df[!,:request_time], bins=24, title="Request Time Histogram", xlabel="Request Time (minutes)", ylabel="Frequency")
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(3, 2))
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
    end

    # Only request with request_time > 0
    for df in df_list
        # Filter out requests with request_time > 0
        df_filtered = filter(row -> row[:call_time] > 0, df)

        # Create a scatter plot for geographical data
        p = scatter(df_filtered[!,:pickup_longitude], df_filtered[!,:pickup_latitude], label="Pickup", color=:blue, xlabel="Longitude", ylabel="Latitude", title="Pickup and Dropoff Locations (Request Time > 0)")
        scatter!(p, df_filtered[!,:dropoff_longitude], df_filtered[!,:dropoff_latitude], label="Dropoff", color=:red)
        push!(plots, p)
    end

    # Create grid layout for the plots
    plot(plots..., layout=(length(df_list), 2), size=(2000, 900))
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

display(plotHistograms(df_list))
display(plotGeographicalData(df_list))
println(getKeyNumbers(df_list, sheet_names))