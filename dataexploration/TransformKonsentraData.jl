# -----
# Packages
# -----
using Distributions, DataFrames, CSV, XLSX, Dates, utils


# ------
# Define parameters
# ------
sheets_5days = ["30.01", "06.02", "23.01", "16.01", "09.01"]
sheets_data = ["Data"]
DoD = 0.3 # Degree of dynamism
ageLimit = 18
serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
callBuffer = 2*60 # 2 hours buffer


# ------
# Function to determine pre-known requests
# ------
function preKnownRequests(df, DoD, serviceWindow, callBuffer)
    geo_dist = Geometric(DoD)
    known_requests = Array{Bool,1}(undef, nrow(df))

    for i in 1:nrow(df)
        # Ensure request can satisfy call time constraint
        request_time = df[!,:request_time][i]
        if request_time < serviceWindow[1] + callBuffer
            known_requests[i] = true  # Known by default if request too early
        else
            # Randomly decide if pre-known using geometric distribution
            known_requests[i] = (rand(geo_dist) == 1)
        end
    end

    return known_requests
end


# ------
# Function to determine call times
# ------
function callTime(df, serviceWindow, callBuffer,preKnown)

    for i in 1:nrow(df)
        if preKnown[i]
            df[i,"call_time"] = 0
        else
            # Determine call window
            call_window = [serviceWindow[1] - callBuffer, df[i,:request_time] - callBuffer]

            # Determine call time from normal distribution
            mean = (call_window[2]-call_window[1])/2 + call_window[1]
            call_time_dist = Normal(mean, mean-call_window[1])
            call_time = rand(call_time_dist)
            df[i,"call_time"] = clamp(call_time, call_window[1], call_window[2])
        end  
    end

end

# ------
# Transform request type to right format
# ------
function transformRequestType(df)
    df[!,:request_type] = map(row -> row == "PU" ? 1 : 0, df[!,:request_type])
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

    # id 
    ids = collect(1:nrow(dfFilter))

    # Make new dataframe with right coloumns
    dfTransformed = DataFrame(
        id = ids,
        pickup_latitude = dfFilter[!,"From LAT"],
        pickup_longitude = dfFilter[!,"From LON"],
        dropoff_latitude = dfFilter[!,"To LAT"],
        dropoff_longitude = dfFilter[!,"To LON"],
        request_type = dfFilter[!,"ReqType"],
        request_time = dfFilter[!,"ReqTime"],
        mobility_type = dfFilter[!,"SpaceType"],
        call_time = zeros(Float64, nrow(dfFilter))
    )
    
    # Transform request type
    transformRequestType(dfTransformed)

    # Determine pre-known requests
    preKnown = preKnownRequests(dfTransformed, DoD, serviceWindow, callBuffer)

    # Determine call time
    callTime(dfTransformed, serviceWindow, callBuffer, preKnown)

    return dfTransformed

    
end


# ------
# Process all sheets from both Excel files
# ------
for sheet in sheets_5days
    dfTransformed = transformData(sheet, "Data/Konsentra/Data5DaysMarch2018.xlsx")
    CSV.write("Data/Konsentra/TransformedData_$sheet.csv", dfTransformed)
end

for sheet in sheets_data
    dfTransformed = transformData(sheet, "Data/Konsentra/Data.xlsx")
    CSV.write("Data/Konsentra/TransformedData_$sheet.csv", dfTransformed)
end
