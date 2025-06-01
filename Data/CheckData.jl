using CSV, DataFrames


Case = "Dynamisk"
Folder = "Data/Konsentra/"*Case*"_v2/500/"

# Load the data
df = CSV.read(Folder*"GeneratedRequests_500_1.csv", DataFrame)


if Case == "Dynamisk"
    # Check 1: call_time must be between 1 and 2 hours (60–120 min) before request_time, if call_time ≠ 0
    invalid_time_rows = df[(df.call_time .!= 0) .&& ((df.request_time .- df.call_time .< 60) .|| (df.request_time .- df.call_time .> 120)), :]

    # Report invalid rows for check 1
    println("Invalid call_time entries (not 1–2 hrs before request_time):")
    show(invalid_time_rows, allcols=true)

    # Check 2: At least 40% of rows should have call_time == 0
    total_rows = nrow(df)
    zero_call_time_count = count(df.call_time .== 0)
    zero_call_time_ratio = zero_call_time_count / total_rows
    println("zero_call_time_ratio: ", zero_call_time_ratio)

    # Filter rows with call_time ≠ 0
    nonzero_calls = df[df.call_time .!= 0, :]

    # Compute time differences
    time_diffs = nonzero_calls.request_time .- nonzero_calls.call_time

    # Get min and max
    min_diff = minimum(time_diffs)
    max_diff = maximum(time_diffs)

    println("Minimum time between call and request: $min_diff minutes")
    println("Maximum time between call and request: $max_diff minutes")

else
    # Check 1: call_time must be between 1 and 2 hours (60–120 min) before request_time, if call_time ≠ 0
    invalid_time_rows = df[(df.call_time .!= 0) .&& ( (df.request_time .- df.call_time .< 120)), :]

    # Report invalid rows for check 1
    println("Invalid call_time entries (not 1–2 hrs before request_time):")
    show(invalid_time_rows, allcols=true)

    # Check 2: At least 60% of rows should have call_time == 0
    total_rows = nrow(df)
    zero_call_time_count = count(df.call_time .== 0)
    zero_call_time_ratio = zero_call_time_count / total_rows
    println("zero_call_time_ratio: ", zero_call_time_ratio)

    # Filter rows with call_time ≠ 0
    nonzero_calls = df[df.call_time .!= 0, :]

    # Compute time differences
    time_diffs = nonzero_calls.request_time .- nonzero_calls.call_time

    # Get min and max
    min_diff = minimum(time_diffs)
    max_diff = maximum(time_diffs)

    println("Minimum time between call and request: $min_diff minutes")
    println("Maximum time between call and request: $max_diff minutes")
end