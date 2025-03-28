# -----
# Packages
# -----

using Distributions, DataFrames, CSV, XLSX, Dates, utils
using StatsBase

export preKnownRequests, callTime


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
function preKnownRequests(df, DoD, serviceWindow, callBuffer)
    totalNumberKnown = round(Int, DoD * nrow(df))
    numberKnownDueToTime = 0
    known_requests = fill(false, nrow(df))
    requestWithLaterTime = Int[]
    probabiltyRequest = Float64[]
    
    # Calculate direct pickup time for drop off requests
    if df[!,:request_type] == 0
        pick_up_location = (Float64(df[!,:pickup_latitude]), Float64(df[!,:pickup_longitude]))
        drop_off_location = (Float64(df[!,:dropoff_latitude]), Float64(df[!,:dropoff_longitude]))
        _, time = getDistanceAndTimeMatrixFromLocations([pick_up_location, drop_off_location])
        df[!,"direct_drive_time"] = time[1,2]
    end

    # Known due to time
    for i in 1:nrow(df)
        request_time = df[!,:request_time][i]
        if  request_time < serviceWindow[1] + callBuffer || (df[i,:request_type] == 0 && df[i, :request_time]- df[i,"direct_drive_time"] < serviceWindow[1] + callBuffer)
            known_requests[i] = true  # Known by default if request too early
            numberKnownDueToTime += 1
        else
            push!(requestWithLaterTime, i)
            push!(probabiltyRequest, serviceWindow[2]-request_time)
        end
    end

    # Known due to probabilty and degree of dynamism
    findNumberKnown = totalNumberKnown - numberKnownDueToTime
    if findNumberKnown < 0
        throw(ArgumentError("Degree of dynamism too low. Could be: " * string(numberKnownDueToTime / nrow(df))))
    end

    # Select indices based on weighted probability
    probabilityRequest = probabiltyRequest ./ sum(probabiltyRequest)
    selectedIndices = sample(requestWithLaterTime, Weights(probabilityRequest), findNumberKnown; replace=false)
    
    for idx in selectedIndices
        known_requests[idx] = true
    end

    return known_requests
end


# ------
# Function to determine call times
# ------
function callTime(df, serviceWindow, callBuffer, preKnown)
    for i in 1:nrow(df)
        if preKnown[i]
            df[i, "call_time"] = 0

        elseif df[i, :request_time] == serviceWindow[1] + callBuffer || (df[i,:request_type] == 0 && df[i, :request_time]- df[i,"direct_drive_time"] == serviceWindow[1] + callBuffer)
            df[i, "call_time"] = serviceWindow[1]
        else
            # Determine latest call time 
            if df[i,:request_type] == 1 # Pick up 
                call_window = [serviceWindow[1], df[i, :request_time] - callBuffer]
            else # Drop off 
                direct_pick_up_time = df[i, :request_time] - df[i,"direct_drive_time"]
                call_window = [serviceWindow[1],direct_pick_up_time - callBuffer]
            end

            # Generate call time from a uniform distribution
            call_time = floor(rand(Uniform(call_window[1], call_window[2])))
            df[i, "call_time"] = call_time
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
# Function to save key numbers
# ------
function saveKeyNumbers(df,callBuffer,serviceWindow)
    key_numbers = DataFrame(
        n_requests = nrow(df),
        n_offline = sum(df[!,:call_time] .== 0),
        naturalDOD = sum(df[!,:request_time] .< serviceWindow[1]+callBuffer) / nrow(df),
        forcedDOD = sum(df[!,:call_time] .== 0) / nrow(df),
    )
    return key_numbers
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
        call_time = zeros(Float64, nrow(dfFilter)),
        direct_drive_time = zeros(Int, nrow(dfFilter))
    )
    
    # Transform request type
    transformRequestType(dfTransformed)

    # Determine pre-known requests
    preKnown = preKnownRequests(dfTransformed, DoD, serviceWindow, callBuffer)

    # Determine call time
    callTime(dfTransformed, serviceWindow, callBuffer, preKnown)

    # Save key numbers
    key_numbers = saveKeyNumbers(dfTransformed,callBuffer,serviceWindow)
    println(key_numbers)

    return dfTransformed

    
end


# ------
# Process all sheets from both Excel files
# ------
#for sheet in sheets_5days
#    dfTransformed = transformData(sheet, "Data/Konsentra/Data5DaysMarch2018.xlsx")
#    CSV.write("Data/Konsentra/TransformedData_$sheet.csv", dfTransformed)
#end

#for sheet in sheets_data
#    dfTransformed = transformData(sheet, "Data/Konsentra/Data.xlsx")
#    CSV.write("Data/Konsentra/TransformedData_$sheet.csv", dfTransformed)
#end
