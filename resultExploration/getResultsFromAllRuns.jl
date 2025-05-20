using XLSX, CSV, DataFrames

# Parameters
methods = ["Anticipation", "BaseCase"]
run_tags = ["run1", "run2"]
anticipation_Degrees = [0.4, 0.5]
n_requests_list = [20, 100, 300, 500]
date = "2025-05-20"
base_dir = joinpath(@__DIR__, "results")
nRuns = 5
nameOfExcel = "Result_20052025_long.xlsx"


# Function to convert a column index to an Excel-style column letter (e.g., 1 -> "A", 2 -> "B")
function col2name(col_index::Int)
    col_name = ""
    while col_index > 0
        col_index -= 1
        col_name = string(Char('A' + col_index % 26), col_name)
        col_index ÷= 26
    end
    return col_name
end



XLSX.openxlsx(nameOfExcel, mode="w") do xf
    # Store base case averages for comparison
    basecase_averages = Dict{Int, Vector{Float64}}()

    # -------- BASE CASE ----------
    method = "BaseCase"
    sheet = XLSX.addsheet!(xf, method)
    current_row = 1  # Track where we are writing on the sheet

    for n_requests in n_requests_list
        # Write metadata
        sheet["A$current_row"] = "Method: $method"
        current_row += 1
        sheet["A$current_row"] = "Number of requests: $n_requests"
        current_row += 1

        method_file = method  # ✅ Fix: set correct folder name for base case

        values = zeros(17)

        for i in 1:nRuns
            filepath = joinpath(base_dir, date, run_tags[i],"BaseCase", string(n_requests), "results.csv")

            if isfile(filepath)
                df = CSV.read(filepath, DataFrame)

                if i == 1
                    # Write headers
                    for (j, col_name) in enumerate(names(df))
                        if j == 1
                            continue  # Skip the first column (index)
                        end
                        col_letter = col2name(j)
                        sheet["$col_letter$current_row"] = col_name
                    end
                    current_row += 1
                end

                # Write run tag
                sheet["A$current_row"] = "Run: $i"

                for row in eachrow(df)
                    for (j, col_name) in enumerate(names(df))
                        if j == 1
                            continue
                        end
                        value = row[col_name]
                        col_letter = col2name(j)
                        sheet["$col_letter$current_row"] = string(value)
                        values[j] += value
                    end
                    current_row += 1
                end
            else
                println("File not found: $filepath")
            end
        end

        # Write average values
        sheet["A$current_row"] = "Average: "
        averages = zeros(17)
        for j in 2:17
            averages[j] = values[j] / nRuns
            col_letter = col2name(j)
            sheet["$col_letter$current_row"] = string(averages[j])
        end

        # ✅ Save averages to dictionary for later comparison
        basecase_averages[n_requests] = averages

        current_row += 2
    end

    newSheetName = "Comparison"
    comparison_sheet = XLSX.addsheet!(xf, newSheetName)  # this is the actual sheet
    comparison_sheet["A1"] = string("Method")
    comparison_sheet["B1"] = string("Anticipation Degree")
    comparison_sheet["C1"] = string("Number of requests")
    comparison_sheet["D1"] = string("TotalElapsedTime")
    comparison_sheet["E1"] = string("AverageResponseTime")
    comparison_sheet["F1"] = string("EventsInsertedByALNS")
    comparison_sheet["G1"] = string("nTaxi")
    comparison_sheet["H1"] = string("TotalCost")
    comparison_sheet["I1"] = string("TotalDistance")
    comparison_sheet["J1"] = string("TotalIdleTime")
    comparison_sheet["K1"] = string("TotalIdleTimeWithCustomer")
    comparison_sheet["L1"] = string("TotalRideTime")
    comparison_sheet["M1"] = string("TotalDirectRideTime")
    comparison_sheet["N1"] = string("TotalActualRideTime")
    comparison_sheet["O1"] = string("nOfflineRequests")
    comparison_sheet["P1"] = string("UnservicedOfflineRequest")
    comparison_sheet["Q1"] = string("nOnlineRequests")
    comparison_sheet["R1"] = string("UnservicedOnlineRequests")
    comparison_sheet["S1"] = string("AveragePercentRideSharing")  # Add this line to set the header for the new column

    current_row_comparison = 2  # Track where we are writing on the comparison sheet

    # --------- ANTICIPATION ---------
    for method in methods
        sheet = XLSX.addsheet!(xf, method)
        current_row = 1  # Track where we are writing on the sheet

        for n_requests in n_requests_list
            for degree in anticipation_Degrees
                # Write metadata
                sheet["A$current_row"] = "Method: $method"
                current_row += 1
                sheet["A$current_row"] = "Anticipation Degree: $degree"
                current_row += 1
                sheet["A$current_row"] = "Number of requests: $n_requests"
                current_row += 1

                # Save value to average 
                values = zeros(17)

                for i in 1:nRuns
                    file = date * "_run" * string(i)
                    method_file = string(method, "_", degree)
                    filepath = joinpath(base_dir, date, run_tags[i],method_file, string(n_requests), "results.csv")

                    if isfile(filepath)
                        df = CSV.read(filepath, DataFrame)

                        if i == 1
                            # Write headers
                            for (j, col_name) in enumerate(names(df))
                                if j == 1
                                    continue  # Skip the first column (index)
                                end
                                col_letter = col2name(j)  # Use your own col2name function
                                sheet["$col_letter$current_row"] = col_name
                            end
                            current_row += 1
                        end

                        # Write run tag
                        sheet["A$current_row"] = "Run: $i"

                        # Write each row of data manually
                        for row in eachrow(df)
                            for (j, col_name) in enumerate(names(df))
                                if j == 1
                                    continue  # Skip the first column (index)
                                end
                                value = row[col_name]
                                col_letter = col2name(j)  # Use your own col2name function here as well
                                sheet["$col_letter$current_row"] = string(value)
                                values[j] += value  # Accumulate values for averaging
                            end
                            current_row += 1
                        end
                    else
                        println("File not found: $filepath")
                    end
                end

                # Write average values
                sheet["A$current_row"] = "Average: "
                for j in 2:17
                    col_letter = col2name(j)  # Use your own col2name function here as well
                    sheet["$col_letter$current_row"] = string(values[j]/nRuns)  # Write average value
                end

                # Add comparison to base case 
                comparison_sheet["A$current_row_comparison"] = string(method) 
                comparison_sheet["B$current_row_comparison"] = string(degree) 
                comparison_sheet["C$current_row_comparison"] = string(n_requests) 
                for j in 1:17
                    col_letter = col2name(j+2)  
                    basecase_value = basecase_averages[n_requests][j]
                    anticipation_value = values[j] / nRuns
                    difference = anticipation_value - basecase_value
                    comparison_sheet["$col_letter$current_row_comparison"] = difference
                end
                comparison_sheet["T$current_row_comparison"] = ((values[14] / nRuns) -basecase_averages[n_requests][14]) + ((values[16] / nRuns) -basecase_averages[n_requests][16])
                current_row_comparison += 1


                current_row += 2  # space between degree blocks
            end

        end
    end
end
