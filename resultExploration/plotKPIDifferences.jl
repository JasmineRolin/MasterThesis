using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

# Inputs
#methods = ["BaseCase", "AnticipationKeepExpected_online"]
#nRequestList = [100]
methods = ["BaseCase", "AnticipationKeepExpected_long_long_two_online"]
nRequestList = [300]

gamma = 0.5
date = "Final_anticiaption"

#==========================#
# Get KPIs for different methods
#==========================#
for n in nRequestList
    methodList = methods

    # Read CSV files
    df1 = CSV.read("resultExploration/results/$date/$(methodList[1])/$n/results_avgOverRuns.csv", DataFrame)
    df2 = CSV.read("resultExploration/results/$date/$(methodList[2])/$n/results_avgOverRuns.csv", DataFrame)

    println("Comparing $(methodList[1]) with $(methodList[2])")

    # Compute KPI differences
    diffIdleTimeMean = df1.TotalIdleTime_mean .- df2.TotalIdleTime_mean
    diffIdleTimeMeanWithCustomer = df1.TotalIdleTimeWithCustomer_mean .- df2.TotalIdleTimeWithCustomer_mean
    diffExcessRideTimeMean = (df1.TotalActualRideTime_mean .- df1.TotalDirectRideTime_mean)./(nRequestList[1].-df1.nTaxi_mean) .-
                             (df2.TotalActualRideTime_mean .- df2.TotalDirectRideTime_mean)./(nRequestList[1].-df2.nTaxi_mean)
    diffAveragePercentRideSharing_mean = df1.AveragePercentRideSharing_mean .- df2.AveragePercentRideSharing_mean

    # Print mean differences
    println("diffIdleTimeMean: ", diffIdleTimeMean)
    println("diffIdleTimeMeanWithCustomer: ", diffIdleTimeMeanWithCustomer)
    println("diffExcessRideTimeMean: ", diffExcessRideTimeMean)
    println("diffAveragePercentRideSharing_mean: ", diffAveragePercentRideSharing_mean)

    println("Mean Idle Time Difference: ", mean(diffIdleTimeMean))
    println("Mean Idle Time with Customer Difference: ", mean(diffIdleTimeMeanWithCustomer))
    println("Mean Excess Ride Time Difference: ", mean(diffExcessRideTimeMean))
    println("Mean Average Percent Ride Sharing Difference: ", mean(diffAveragePercentRideSharing_mean))
    # Plot the differences
    p1 = plot(diffIdleTimeMean, label="Idle Time Mean Difference", xlabel="Requests", ylabel="Difference (s)", title="Idle Time Mean Difference")
    plot!(diffIdleTimeMeanWithCustomer, label="Idle Time Mean with Customer Difference", xlabel="Requests", ylabel="Difference (s)", title="Idle Time Mean with Customer Difference")
    plot!(diffExcessRideTimeMean, label="Excess Ride Time Mean Difference", xlabel="Requests", ylabel="Difference (s)", title="Excess Ride Time Mean Difference")
    nRows = nrow(df1)
    xtickLabel = ["Scenario $(i)" for i in 1:nRows]
    display(p1)
    plot(p1, layout = (3, 1), size = (800, 1200), legend = :topright)

    #savefig("resultExploration/results/" * date * "/" * methodList[1] * "/" * string(n) * "/kpi_differences.png")
end


