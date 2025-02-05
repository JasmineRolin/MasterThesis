using XLSX
using DataFrames
using Plots
using Dates
using utils

# Open file 
sheets = ["30.01","06.02","23.01","16.01","09.01"]
df = DataFrame(XLSX.readtable("Data/Konsentra/Data5DaysMarch2018.xlsx", "23.01"))
df = DataFrame(XLSX.readtable("Data/Konsentra/Data.xlsx", "Data"))


df[!,"Age"] = Int8.(df[!,"Age"]) # convert age to int 
df[!,"ReqTime"] = minutesSinceMidnight.(string.(df[!,"ReqTime"]))


# Stats 
nRequests = nrow(df)


#==
 Information about age of customers
==#
# How many requests are for adults? 
ageLimit = 18 
nAboveAgeLimit = sum(df[!,"Age"] .>= ageLimit)



# Create histogram of ages
ageHistogram = histogram(df[!,"Age"], bins=10, color=:skyblue, xlabel="Age", ylabel="Count", title="Age Distribution")
display(ageHistogram)


#==
 Extract data for specific customers
==#
# Filter data for customers above 18 years old
dfAdults = filter(row -> row[:Age] >= ageLimit, df)
filter_words = ["V.G.S", "VOKSENOPPLÆRING", "VOKSENOPPLÆRIN", "voksenopplæring","VGS","Gymnas","GYMNAS","SKOLE","DRØMTORP","OPPEGÅRD"]
dfFilter = filter(row -> all(word -> !contains(row[:To], word) && !contains(row[:From], word), filter_words), dfAdults)

# Display 
data = DataFrame(
    rows = ["No. requests","No. request above age $ageLimit", "No. filtered requests"],
    results = [nRequests,nAboveAgeLimit,nrow(dfFilter)]
)

println(data)


#==
 Information about request times 
==# 
# Create histogram of request times for pick up activities 
requestHistogram = histogram(df[!,"ReqTime"], bins=24, color=:skyblue, xlabel="Minutes since midnigth", ylabel="Count", title="Request Time Distribution")
display(requestHistogram)

requestHistogram18 = histogram(dfAdults[!,"ReqTime"], bins=24, color=:skyblue, xlabel="Minutes since midnigth", ylabel="Count", title="Request Time Distribution for people over 18")
display(requestHistogram18)

requestHistogramFilter = histogram(dfFilter[!,"ReqTime"], bins=24, color=:skyblue, xlabel="Minutes since midnigth", ylabel="Count", title="Filtered Request Time Distribution")
display(requestHistogramFilter)

#==
 Geographical information about pick up and drop off locations
==#
using DataFrames, Plots, OpenStreetMapXPlot, OpenStreetMapX

# Helper function
function unzip(coords)
    latitudes = [coord[1] for coord in coords]
    longitudes = [coord[2] for coord in coords]
    return latitudes, longitudes
end

# OSM file
map_file_path = "C:/Users/Astrid/OneDrive - Danmarks Tekniske Universitet/Dokumenter/Master Thesis/MasterThesis/Data/map"
map_data = OpenStreetMapX.get_map_data(map_file_path)

# Extract coordinates for pickups and drop-offs
pickup_coords = [(df[!,"From LAT"][i], df[!,"From LON"][i]) for i in 1:nrow(df)]
dropoff_coords = [(df[!,"To LAT"][i], df[!,"To LON"][i]) for i in 1:nrow(df)]

# Convert coordinates to longitude and latitude vectors
pickup_lat, pickup_lon = unzip(pickup_coords)
dropoff_lat, dropoff_lon = unzip(dropoff_coords)

# Plot the map with pickups and drop-offs
test2 = plot(size=(800, 600), title="Pickup and Dropoff Locations")
scatter!(pickup_lon, pickup_lat, markercolor=:blue, label="Pickups")
scatter!(dropoff_lon, dropoff_lat, markercolor=:red, label="Drop-offs")

xlabel!("Longitude")
ylabel!("Latitude")

display(test2)


#==
 Geographical information about pick up and drop off locations over 18 years old
==#

# Extract coordinates for pickups and drop-offs
pickup_coords = [(dfAdults[!,"From LAT"][i], dfAdults[!,"From LON"][i]) for i in 1:nrow(dfAdults)]
dropoff_coords = [(dfAdults[!,"To LAT"][i], dfAdults[!,"To LON"][i]) for i in 1:nrow(dfAdults)]

# Convert coordinates to longitude and latitude vectors
pickup_lat, pickup_lon = unzip(pickup_coords)
dropoff_lat, dropoff_lon = unzip(dropoff_coords)

# Plot the map with pickups and drop-offs
figure18 = plot(size=(800, 600), title="Pickup and Dropoff Locations for people over 18 years old")
scatter!(pickup_lon, pickup_lat, markercolor=:blue, label="Pickups")
scatter!(dropoff_lon, dropoff_lat, markercolor=:red, label="Drop-offs")

xlabel!("Longitude")
ylabel!("Latitude")

display(figure18)

#==
 Geographical information about pick up and drop off locations for dfFilter
==#
# Extract coordinates for pickups and drop-offs
pickup_coords = [(dfFilter[!,"From LAT"][i], dfFilter[!,"From LON"][i]) for i in 1:nrow(dfFilter)]
dropoff_coords = [(dfFilter[!,"To LAT"][i], dfFilter[!,"To LON"][i]) for i in 1:nrow(dfFilter)]

# Convert coordinates to longitude and latitude vectors
pickup_lat, pickup_lon = unzip(pickup_coords)
dropoff_lat, dropoff_lon = unzip(dropoff_coords)

# Plot the map with pickups and drop-offs
figureFilter = plot(size=(800, 600), title="Filtered Pickup and Dropoff Locations for people")
scatter!(pickup_lon, pickup_lat, markercolor=:blue, label="Pickups")
scatter!(dropoff_lon, dropoff_lat, markercolor=:red, label="Drop-offs")

xlabel!("Longitude")
ylabel!("Latitude")

display(figureFilter)


#==
 Display
==#

