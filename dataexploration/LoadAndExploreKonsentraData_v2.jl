using XLSX
using DataFrames
using Plots
using Dates
using utils

# Define sheet names for Data5DaysMarch2018.xlsx and Data.xlsx
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]

# Helper function to unzip coordinates
function unzip(coords)
    latitudes = [coord[1] for coord in coords]
    longitudes = [coord[2] for coord in coords]
    return latitudes, longitudes
end

# Array to store all generated plots
plots_list = Plot[]  # Ensure the list has the correct type

# Helper function to create and store plots
function process_sheet(sheet_name, filename)
    df = DataFrame(XLSX.readtable(filename, sheet_name))
    
    df[!,"Age"] = Int8.(df[!,"Age"]) # convert age to int 
    df[!,"ReqTime"] = minutesSinceMidnight.(string.(df[!,"ReqTime"]))

    # Filter
    ageLimit = 18
    dfAdults = filter(row -> row[:Age] >= ageLimit, df)
    filter_words = ["V.G.S", "VOKSENOPPLÆRING", "VOKSENOPPLÆRIN", "voksenopplæring","VGS","Gymnas","GYMNAS","SKOLE","DRØMTORP","OPPEGÅRD"]
    dfFilter = filter(row -> all(word -> !contains(row[:To], word) && !contains(row[:From], word), filter_words), dfAdults)

    # Request time distribution for filtered data
    requestHistogramFilter = histogram(dfFilter[!,"ReqTime"], bins=24, color=:skyblue, xlabel="Minutes since midnight", ylabel="Count", title="Filtered Request Time Distribution - $sheet_name")

    # Save the request time plot
    push!(plots_list, requestHistogramFilter)

    # Extract coordinates for pickups and drop-offs
    pickup_coords = [(dfFilter[!,"From LAT"][i], dfFilter[!,"From LON"][i]) for i in 1:nrow(dfFilter)]
    dropoff_coords = [(dfFilter[!,"To LAT"][i], dfFilter[!,"To LON"][i]) for i in 1:nrow(dfFilter)]

    # Convert coordinates to latitude and longitude vectors
    pickup_lat, pickup_lon = unzip(pickup_coords)
    dropoff_lat, dropoff_lon = unzip(dropoff_coords)

    # Plot the map with pickups and drop-offs
    filtered_geo_plot = plot(size=(200, 1000), title="Filtered Pickup and Dropoff Locations - $sheet_name")
    scatter!(filtered_geo_plot, pickup_lon, pickup_lat, markercolor=:blue, label="Pickups")
    scatter!(filtered_geo_plot, dropoff_lon, dropoff_lat, markercolor=:red, label="Drop-offs")
    xlabel!(filtered_geo_plot, "Longitude")
    ylabel!(filtered_geo_plot, "Latitude")

    # Save the pickup and dropoff plot
    push!(plots_list, filtered_geo_plot)
end

# Process all sheets from both Excel files
for sheet in sheets_5days
    process_sheet(sheet, "Data/Konsentra/Data5DaysMarch2018.xlsx")
end

for sheet in sheets_data
    process_sheet(sheet, "Data/Konsentra/Data.xlsx")
end

# Create a grid matrix for gridstack
num_rows = Int(ceil(length(plots_list) / 2))
grid_matrix = reshape(plots_list[1:2*num_rows], num_rows, 2)

# Plot using gridstack
gridstack(grid_matrix)
