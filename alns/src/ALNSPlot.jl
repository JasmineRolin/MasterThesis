module ALNSPlot 

using DataFrames, CSV, Plots, JSON 

#==
 Method to plot ALNS results  
==#
function ALNSResults(specificationsFile::String,ALNSOutputFile::String)
    # TODO: should we also input a solution and somehow save a solution? 

    # Read the CSV file into a DataFrame
    df = CSV.read(ALNSOutputFile, DataFrame)

    # Read specifications 
    specifications = JSON.parsefile(specificationsFile)

end


using JSON
using DataFrames

function create_table_from_json(specifications::Dict)
    # Extract relevant sections from the parsed data
    destroy_methods = specifications["DestroyMethods"]
    repair_methods = specifications["RepairMethods"]
    scenario_name = specifications["Scenario"]["name"]
    
    parameters = specifications["Parameters"]

    # Combine data into a table format
    table_data = [
        ("DestroyMethods", join(destroy_methods, ", ")),
        ("RepairMethods", join(repair_methods, ", ")),
        ("Scenario", scenario_name)
    ]
    
    # Add the parameters to the table
    for (param, value) in parameters
        push!(table_data, (param, string(value)))
    end
    
    # Create a DataFrame
    df = DataFrame(Column1=String[], Column2=String[])
    append!(df, table_data)

    # Return the DataFrame
    return df
end


#==
 Method create plot of cost of run 
==#
function createCostPlot(df::DataFrame)
    using CSV, DataFrames, Plots

    # Extract relevant columns
    iterations = df.Iteration
    total_cost = df.TotalCost
    isAccepted = df.IsAccepted
    isImproved = df.IsImproved
    isNewBest = df.IsNewBest

    # Create the line plot for total cost
    plot = plot(iterations, total_cost, label="Total Cost", linewidth=2, color=:blue, xlabel="Iteration", ylabel="Total Cost", title="ALNS Total Cost Over Iterations")

    # Add yellow dots for accepted solutions
    scatter!(iterations[isAccepted], total_cost[isAccepted], markershape=:circle, color=:yellow, label="Accepted")

    # Add green dots for improved solutions
    scatter!(iterations[isImproved], total_cost[isImproved], markershape=:circle, color=:green, label="Improved")

    # Add green stars for new best solutions
    scatter!(iterations[isNewBest], total_cost[isNewBest], markershape=:star5, color=:green, label="New Best")

    return plot 
end





end 