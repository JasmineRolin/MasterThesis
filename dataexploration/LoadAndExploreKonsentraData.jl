using XLSX
using DataFrames
using Plots
using Dates
using utils

# ------------------------------ 
# Helper script to look at filtered data
# ------------------------------

# Define sheet names for Data5DaysMarch2018.xlsx and Data.xlsx
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]

# Helper function to unzip coordinates
function unzip(coords)
    latitudes = [coord[1] for coord in coords]
    longitudes = [coord[2] for coord in coords]
    return latitudes, longitudes
end

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

    return dfFilter
end

filtered_data = []

# Process all sheets from both Excel files
sheet = sheets_5days[1]
filtered = process_sheet(sheet, "Data/Konsentra/Data5DaysMarch2018.xlsx")

