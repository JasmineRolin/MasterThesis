# -----
# Packages
# -----
using Distributions, DataFrames


# ------
# Define parameters
# ------
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]
DoD = 0.4 # Degree of dynamism
ageLimit = 18
serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
callBuffer = 2*60 # 2 hours buffer


# ------
# Function to determine pre-known requests
# ------
function preKnownRequests(df, DoD)
    # Check if request time can satisfy call time constraint else they will be known in the offline problem
    if request_time < serviceWindow[1]+callBuffer
        return 0
    end

    # Define geometric distribution
    geo_dist = Geometric(DoD)

    # Sort by PickupTime (earlier requests first)
    sort!(df, :request_time)

    # Assign KnownBeforehand based on geometric distribution for requests in service window and not known beforehand
    


    df[!,"KnownBeforehand"] = [rand(geo_dist) == 1 for _ in 1:nrow(df)]

    return df
end


# ------
# Determine call time
# ------
function callTime(request_time, serviceWindow, callBuffer)

    # Determine call window
    call_window = [serviceWindow - callBuffer, request_time - callBuffer]

    mean = (call_window[2]-call_window[1])/2
    call_time_dist = Normal(mean, mean-call_window[1])
    df[!,"CallTime"] = [pickup - Dates.Minute(rand(call_time_dist)) for pickup in df[!,"PickupTime"]]

    return df
end

# ------
# Filter data
# ------
function filterData(df, ageLimit, serviceWindow)
    
    # Filter data for customers above 18 years old and not going to a School
    dfAdults = filter(row -> row[:Age] >= ageLimit, df)
    filter_words = ["V.G.S", "VOKSENOPPLÆRING", "VOKSENOPPLÆRIN", "voksenopplæring","VGS","Gymnas","GYMNAS","SKOLE","DRØMTORP","OPPEGÅRD"]
    dfFilter = filter(row -> all(word -> !contains(row[:To], word) && !contains(row[:From], word), filter_words), dfAdults)

    # Remove request that is outside the service window
    dfFilter = filter(row -> row[:ReqTime] >= serviceWindow[1] && row[:ReqTime] <= serviceWindow[2], dfFilter)

    return dfFilter
end

# ------
# function transform data
# ------
function transformData(sheet_name, filename)
    # Read data
    df = DataFrame(XLSX.readtable(filename, sheet_name))
    df[!,"Age"] = Int8.(df[!,"Age"]) # convert age to int 
    df[!,"ReqTime"] = minutesSinceMidnight.(string.(df[!,"ReqTime"]))

    # Filter data
    dfFilter = filterData(df, ageLimit, serviceWindow)

    # Make new dataframe with right coloumns
    dfTransformed = DataFrame(
        pickup_latitude = dfFilter[!,"From LAT"],
        pickup_longitude = dfFilter[!,"From LON"],
        dropoff_latitude = dfFilter[!,"To LAT"],
        dropoff_longitude = dfFilter[!,"To LON"],
        request_type = dfFilter[!,"ReqType"],
        request_time = dfFilter[!,"ReqTime"],
        mobility_type = dfFilter[!,"MobilityType"],
        call_time = zeros(Int8, nrow(dfFilter))
    )

    # Determine pre-known requests
    dfTransformed = preKnownRequests(dfTransformed, DoD)

    # Determine call time
    dfTransformed = callTime(dfTransformed, serviceWindow, callBuffer)

    return dfTransformed

    
end

# ------
# Process all sheets from both Excel files
# ------
for sheet in sheets_5days
    dfTransformed = transformData(sheet, "Data/Konsentra/Data5DaysMarch2018.xlsx")
    CSV.write("Data/Konsentra/TransformedData_$sheet.csv", dfTransformed)
end

