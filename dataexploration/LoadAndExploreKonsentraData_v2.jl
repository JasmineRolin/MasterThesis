using XLSX
using DataFrames
using Plots
using Dates
using utils

# Define sheet names for Data5DaysMarch2018.xlsx and Data.xlsx
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]

# Prepare layout for 6x2 grid
layout = @layout [a b a b a b a b a b a b a b a b a b]

# Create a plot object to store the individual subplots
p = plot(layout=layout, size=(1200, 2000))

# Helper function to unzip coordinates
function unzip(coords)
    latitudes = [coord[1] for coord in coords]
    longitudes = [coord[2] for coord in coords]
    return latitudes, longitudes
end

# Helper function to create and add plots to the layout grid
function process_sheet(sheet_name, filename, p, sheet_index)
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
    
    # Plot the request time distribution in the first column of the layout
    plot!(p, requestHistogramFilter, subplot=2 * (sheet_index - 1) + 1)

    # Extract coordinates for pickups and drop-offs
    pickup_coords = [(dfFilter[!,"From LAT"][i], dfFilter[!,"From LON"][i]) for i in 1:nrow(dfFilter)]
    dropoff_coords = [(dfFilter[!,"To LAT"][i], dfFilter[!,"To LON"][i]) for i in 1:nrow(dfFilter)]

    # Convert coordinates to latitude and longitude vectors
    pickup_lat, pickup_lon = unzip(pickup_coords)
    dropoff_lat, dropoff_lon = unzip(dropoff_coords)

    # Plot the map with pickups and drop-offs
    filtered_geo_plot = plot(size=(600, 400), title="Filtered Pickup and Dropoff Locations - $sheet_name")
    scatter!(filtered_geo_plot, pickup_lon, pickup_lat, markercolor=:blue, label="Pickups")
    scatter!(filtered_geo_plot, dropoff_lon, dropoff_lat, markercolor=:red, label="Drop-offs")
    xlabel!(filtered_geo_plot, "Longitude")
    ylabel!(filtered_geo_plot, "Latitude")

    # Plot the pickup and dropoff map in the second column of the layout
    plot!(p, filtered_geo_plot, subplot=2 * (sheet_index - 1) + 2)
end

# Process all sheets from both Excel files
sheet_index = 1
for sheet in sheets_5days
    process_sheet(sheet, "Data/Konsentra/Data5DaysMarch2018.xlsx", p, sheet_index)
    sheet_index += 1
end

sheet_index = 1
for sheet in sheets_data
    process_sheet(sheet, "Data/Konsentra/Data.xlsx", p, sheet_index)
    sheet_index += 1
end

# Display the final plot
display(p)
