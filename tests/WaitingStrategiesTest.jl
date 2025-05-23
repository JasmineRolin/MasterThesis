
using waitingstrategies, domain, offlinesolution, utils, simulationframework, onlinesolution
using Plots, JSON, Test
using Plots.PlotMeasures

#==
        !!!# OBS OBS OBS OBS OBS #!!!!!

        To run the scenarios with short call time (in Data/WaitingStrategies)
        - change MAX_DELAY = 15 and MAX_EARLY_ARRIVAL = 5 in instance reader 
        - outcomment check for buffer in instance reader in readRequests
                if callTime > requestTime - bufferTime
                    throw(ArgumentError(string("Call time is not before required buffer period for request: ",id)))
                end

==#

print("\033c")

# Receive command line arguments 

    # OBS!!! OBS!! #
        gridSize = 5
    # OBS!!! OBS!! #

n = 300
gamma = 0.7
i = 10
relocateVehicles = true
startFileIndex = 1
endFileIndex = 20
nPeriods = 48
displayPlots = false

# Find period length 
maximumTime = 24*60 
periodLength = Int(maximumTime / nPeriods)

# Retrieve historic request files 
historicIndexes = setdiff(collect(startFileIndex:endFileIndex),i)
historicRequestFiles = Vector{String}()
for j in historicIndexes
    push!(historicRequestFiles,"Data/DataWaitingStrategies2/$(n)/GeneratedRequests_$(n)_$(j).csv")
end


# File names 
vehiclesFile = string("Data/DataWaitingStrategies2/",n,"/Vehicles_",n,"_",gamma,".csv")
parametersFile = "tests/resources/ParametersShortCallTime.csv"
outPutFolder = "runfiles/output/Waiting/"*string(n)
gridFile = "Data/Konsentra/grid_$(gridSize).json"

outputFiles = Vector{String}()

requestFile = string("Data/DataWaitingStrategies2/",n,"/GeneratedRequests_",n,"_",i,".csv")
distanceMatrixFile = string("Data/DataWaitingStrategies2/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
timeMatrixFile =  string("Data/DataWaitingStrategies2/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
scenarioName = string("Gen_Data_",n,"_",gamma,"_",i)
push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_"*string(relocateVehicles)*".json")


# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)

# Plot scenario 
pRequests = plotRequestsAndVehiclesWait(scenario,scenario.grid,n,gamma)
display(pRequests)


println("\t nOfflineRequests: ",length(scenario.offlineRequests))

# Simulate scenario 
useALNS = true
solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = displayPlots,saveResults = false,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=relocateVehicles,nTimePeriods=nPeriods,periodLength=periodLength,ALNS = useALNS);

state = State(solution,scenario.onlineRequests[end],0)
feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#printSolution(solution,printRouteHorizontal)
@test msg == ""
@test feasible == true
println(msg)

#============================================================================#

#==
 Plot time windows of pick ups 
==#
# requests = deepcopy(scenario.requests)
# requests = sort(requests, by = r -> r.pickUpActivity.timeWindow.startTime)
# n = length(requests)
# labels = [string("Request ",r.id) for r in requests]
# start_times = [r.pickUpActivity.timeWindow.startTime for r in requests]
# end_times = [r.pickUpActivity.timeWindow.endTime for r in requests]
# call_times = [r.callTime for r in requests]
# durationsCallTime = end_times .- call_times
# durationsCallTimeStart = start_times .- call_times

# # Plotting
# p = plot(size = (2500,2500),legend=true, xlabel="Minutes after midnight", yticks=(1:n, labels), title="Pickup Time Windows with Call Times for Base Scenario",leftmargin=5mm,topmargin=5mm,rightmargin=5mm,bottommargin=5mm)

# # Add bars for time windows
# y = 1
# label = "Pickup Time Window"
# plot!([start_times[1], end_times[1]], [y, y], lw=10, color=:blue,label=label)
# annotate!([end_times[1]], [y+0.1], text("$(durationsCallTime[1])", :black, 10, :bottom))
# annotate!([start_times[1]], [y+0.1], text("$(durationsCallTimeStart[1])", :black, 10, :bottom))

# for i in 2:n
#     y = i # reverse order to show first request at the top
#     label = ""
#     plot!([start_times[i], end_times[i]], [y, y], lw=10, color=:blue,label=label)
#     annotate!([end_times[i]], [y+0.1], text("$(durationsCallTime[i])", :black, 10, :bottom))
#     annotate!([start_times[i]], [y+0.1], text("$(durationsCallTimeStart[i])", :black, 10, :bottom))
# end

# # Add vertical red lines for call times
# label = "Call Time"
# y = 1
# plot!([call_times[1], call_times[1]], [y-0.3, y+0.3], color=:red, lw=2, linestyle=:solid,label=label)

# for i in 2:n
#     y = i
#     label = ""
#     plot!([call_times[i], call_times[i]], [y-0.3, y+0.3], color=:red, lw=2, linestyle=:solid,label=label)
# end

# display(p)
# savefig(p,"plots/Waiting/PickUpTimeWindows_EXAMPLE.png")


# for r in scenario.onlineRequests
#     println("Request $(r.id), request type $(r.requestType)") 
#     println("\t Call time: $(r.callTime)")
#     println("\t Duration from call time to start TW: $(r.pickUpActivity.timeWindow.startTime - r.callTime)")
#     println("\t Duration from call time to end TW: $(r.pickUpActivity.timeWindow.endTime - r.callTime)")
#     println("\t direct drive time: $(r.directDriveTime)")
#     println("\t pick up time window: ($(r.pickUpActivity.timeWindow.startTime) , $(r.pickUpActivity.timeWindow.endTime))")
#     println("\t drop off time window: ($(r.dropOffActivity.timeWindow.startTime) , $(r.dropOffActivity.timeWindow.endTime))")
# end
