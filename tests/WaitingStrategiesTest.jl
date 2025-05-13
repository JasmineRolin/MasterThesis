
using waitingstrategies, domain, offlinesolution, utils, simulationframework, onlinesolution
using Plots, JSON, Test
using Plots.PlotMeasures

print("\033c")


# Receive command line arguments 
n = 20
gamma = 0.7
i = 13
relocateVehicles = false
gridSize = 5
startFileIndex = 11
endFileIndex = 20
nPeriods = 48

# Find period length 
maximumTime = 24*60 
periodLength = Int(maximumTime / nPeriods)

# Retrieve historic request files 
historicIndexes = setdiff(collect(startFileIndex:endFileIndex),i)
historicRequestFiles = Vector{String}()
for j in historicIndexes
    push!(historicRequestFiles,"Data/DataWaitingStrategies/$(n)/GeneratedRequests_$(n)_$(j).csv")
end


# File names 
vehiclesFile = string("Data/DataWaitingStrategies/",n,"/Vehicles_",n,"_",gamma,".csv")
parametersFile = "tests/resources/ParametersShortCallTime.csv"
outPutFolder = "runfiles/output/Waiting/"*string(n)
gridFile = "Data/Konsentra/grid_$(gridSize).json"

outputFiles = Vector{String}()

requestFile = string("Data/DataWaitingStrategies/",n,"/GeneratedRequests_",n,"_",i,".csv")
distanceMatrixFile = string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
timeMatrixFile =  string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
scenarioName = string("Gen_Data_",n,"_",gamma,"_",i)
push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")


# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)

println("====> SCENARIO: ",scenarioName)
println("\t With historic requests files: ",historicIndexes)
println("\t gamma: ",gamma)
println("\t Relocate vehicles: ",relocateVehicles)
println("\t Grid size: ",gridSize)
println("\t Period length: ",periodLength)
println("\t nOfflineRequests: ",length(scenario.offlineRequests))

# Simulate scenario 
solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = false,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=relocateVehicles,nTimePeriods=nPeriods,periodLength=periodLength);

state = State(solution,scenario.onlineRequests[end],0)
feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
printSolution(solution,printRouteHorizontal)
@test msg == ""
@test feasible == true
#end

dfResults = processResults(outputFiles)
result_file = string(outPutFolder, "/results_", gamma, ".csv")
append_mode = isfile(result_file)
CSV.write(result_file, dfResults; append=append_mode)


# gamma = 0.7
# nData = 20
# n = 50
# i = 2
# gridFile = "Data/Konsentra/grid.json"
# historicIndexes = setdiff(1:nData,i)
# nPeriods =  48 # equiv. 30 minute intervals 
# maximumTime = 24*60 
# periodLength = Int(maximumTime / nPeriods)

# # List of historic requests 
# historicRequestFiles = Vector{String}()
# for j in historicIndexes
#     push!(historicRequestFiles,"Data/Konsentra/$(n)/GeneratedRequests_$(n)_$(j).csv")
# end

# requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
# distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
# timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
# scenarioName = string("Generated_Data_",n,"_",i)
# vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",gamma,".csv")
# parametersFile = "tests/resources/ParametersShortCallTime.csv"

# # Read instance 
# scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)

# outPutFolder = "tests/output/OnlineSimulation/"*string(n)

# relocateVehicles = true
# solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = true,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=relocateVehicles,nTimePeriods=nPeriods,periodLength=periodLength);

# state = State(solution,scenario.onlineRequests[end],0)
# feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
# @test feasible == true
# @test msg == ""
# println(msg)

# for r in scenario.requests[requestBank]
#     println("Request: $(r.id), call time: $(r.callTime)")
# end

# print("end")

# # # Dummy example assuming scenario.onlineRequests is available
# requests = scenario.onlineRequests

# # Prepare data
# n = length(requests)
# labels = [string(r.id) for r in requests]
# start_times = [r.pickUpActivity.timeWindow.startTime for r in requests]
# end_times = [r.pickUpActivity.timeWindow.endTime for r in requests]
# call_times = [r.callTime for r in requests]
# durationsCallTime = end_times .- call_times
# durationsCallTimeStart = start_times .- call_times

# # Plotting
# p = plot(size = (1500,1500),legend=false, xlabel="Time", yticks=(1:n, labels), title="Pickup Time Windows with Call Times")

# # Add bars for time windows
# for i in 1:n
#     y = i # reverse order to show first request at the top
#     plot!([start_times[i], end_times[i]], [y, y], lw=5, color=:blue)
#     annotate!([end_times[i]], [y], text("$(durationsCallTime[i])", :black, 8, :bottom))
#     annotate!([start_times[i]], [y], text("$(durationsCallTimeStart[i])", :green, 8, :bottom))
# end

# # Add vertical red lines for call times
# for i in 1:n
#     y = i
#     plot!([call_times[i], call_times[i]], [y-0.3, y+0.3], color=:red, lw=2, linestyle=:dash)
# end

# display(p)


# for r in scenario.onlineRequests
#     println("Request $(r.id), request type $(r.requestType)") 
#     println("\t Call time: $(r.callTime)")
#     println("\t Duration from call time to start TW: $(r.pickUpActivity.timeWindow.startTime - r.callTime)")
#     println("\t Duration from call time to end TW: $(r.pickUpActivity.timeWindow.endTime - r.callTime)")
#     println("\t direct drive time: $(r.directDriveTime)")
#     println("\t pick up time window: ($(r.pickUpActivity.timeWindow.startTime) , $(r.pickUpActivity.timeWindow.endTime))")
#     println("\t drop off time window: ($(r.dropOffActivity.timeWindow.startTime) , $(r.dropOffActivity.timeWindow.endTime))")
# end



# predictedDemand = generatePredictedDemand(scenario.grid, historicRequestFiles,nPeriods,periodLength)
# vehicleDemand = zeros(Int,nPeriods,scenario.grid.nRows,scenario.grid.nCols)
# planningHorizon = 4 

# avg_min = 0
# avg_max = 10

# demand_min = minimum(predictedDemand)
# demand_max = maximum(predictedDemand)

# for period in 1:nPeriods
#     endPeriod = min(period + planningHorizon, nPeriods)

#     vehicleDemandInPeriod,maxDemandInHorizonPeriod = generatePredictedVehiclesDemandInHorizon(gamma,predictedDemand,period,endPeriod)
#    # gridCell = determineWaitingLocation(scenario.depotLocations,scenario.grid,nRequests, vehicleBalance,period)

#     vehicleDemand[period,:,:] = vehicleDemandInPeriod
#     p4 = heatmap(vehicleDemandInPeriod, 
#     c=:viridis,         # color map
#     clim=(avg_min, avg_max),
#     xlabel="Longitude (grid cols)", 
#     ylabel="Latitude (grid rows)", 
#     title="Vehicle demand",
#     colorbar_title="Vehicle Demand")
#     #scatter!(p4,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:green)
#     #scatter!(p4,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Depot location", color=:red)
   
#     p5 = heatmap(maxDemandInHorizonPeriod[:,:], 
#     c=:viridis,         # color map
#     clim=(demand_min, demand_max),
#     xlabel="Longitude (grid cols)", 
#     ylabel="Latitude (grid rows)", 
#     title="Demand over horizon",
#     colorbar_title="Requests")
#     #scatter!(p5,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:green)
#     #scatter!(p5,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Depot location", color=:red)

#     super_title = plot(title = "Vehicle Demand Overview - period start $((period-1)*periodLength)", grid=false, framestyle=:none)

#     # Combine all into a vertical layout: super title + 3 plots
#     p = plot(super_title, plot(p4,p5, layout=(1,2)), layout = @layout([a{0.01h}; b{0.99h}]), size=(1500,1100))
#     display(p)
# end







# initialSolution, requestBank = simpleConstruction(scenario,scenario.requests)
# state = State(initialSolution,scenario.onlineRequests[end],0)
# feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
# @test feasible == true
# @test msg == ""
# println(msg)

# display(createGantChartOfSolutionOnline(initialSolution,"Final Solution after merge"))

# schedule = deepcopy(solution.vehicleSchedules[2])
# request = scenario.requests[20]
# posPU = 4
# posDO = 4
# feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd =
#  checkFeasibilityOfInsertionAtPosition(request,schedule,posPU,posDO,scenario)

#  const EMPTY_RESULT = (false, -1, -1, Vector{Int}(), Vector{Int}(), Vector{Int}(), typemax(Float64), typemax(Float64), typemax(Int), typemax(Int), Vector{Int}())

# # TODO: delete 
# global countTotal = Ref(0)
# global countFeasible = Ref(0)

# ewa = findBestFeasibleInsertionRoute(request,schedule,scenario)



# arrivalAtDepot = schedule.route[end].startOfServiceTime
# endOfAvailableTimeWindow = schedule.vehicle.availableTimeWindow.endTime
# waitingActivityCompletedRoute = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)), schedule.vehicle,arrivalAtDepot,endOfAvailableTimeWindow)
# schedule.route[end].activity.timeWindow = TimeWindow(arrivalAtDepot,endOfAvailableTimeWindow)
# schedule.route[end].startOfServiceTime = endOfAvailableTimeWindow
# schedule.route[end].endOfServiceTime = endOfAvailableTimeWindow
# schedule.numberOfWalking = vcat(schedule.numberOfWalking,[0])
# schedule.route = vcat(schedule.route[1:(end-1)],[waitingActivityCompletedRoute],[schedule.route[end]])

# printRouteHorizontal(schedule)


# feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd =
#  checkFeasibilityOfInsertionAtPosition(scenario.requests[20],schedule,6,6,scenario)

# insertRequest!(scenario.requests[20],schedule,6,6,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,waitingActivitiesToAdd=waitingActivitiesToAdd)


#   printSolution(solution,printRouteHorizontal)


# # Read grid definition
# gridJSON = JSON.parsefile(gridFile) # TODO: jas - i scenario ? 
# maxLat = gridJSON["max_latitude"]
# minLat = gridJSON["min_latitude"]
# maxLong = gridJSON["max_longitude"]
# minLong = gridJSON["min_longitude"]
# nRows = gridJSON["num_rows"]
# nCols = gridJSON["num_columns"]
# latStep = (maxLat - minLat) / nRows
# longStep = (maxLong - minLong) / nCols

# grid = Grid(maxLat,minLat,maxLong,minLong,nRows,nCols,latStep,longStep)


# averageDemand = generatePredictedDemand(scenario.grid, historicRequestFiles,nPeriods,periodLength)
# #vehicleDemand = generatePredictedVehiclesDemand(scenario.grid, gamma, averageDemand,nPeriods)
# period = Int(ceil(1140/periodLength))
# vehicleDemand = generatePredictedVehiclesDemandInHorizon(gamma,averageDemand,period,period+3)

# #======================================#
# #
# #=====================================#
# depotLocations = findDepotLocations(grid,n)
 
# #Construct solution 
# initialSolution, requestBank = simpleConstruction(scenario,scenario.requests)
# state = State(initialSolution,scenario.onlineRequests[end],0)
# feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
# @test feasible == true
# @test msg == ""
# println(msg)

# printSolution(initialSolution,printRouteHorizontal)

# #Determine waiting location 
# time = 460
# hour = Int(ceil(time / 60))
# vehicleBalance,activeVehiclesPerCell = determineVehicleBalancePrCell(grid,vehicleDemand,initialSolution)

# depotId,location, gridCell = determineWaitingLocation(depotLocations,grid,n,vehicleBalance,hour)




# #==============================#
# # Plot 
# #==============================#
# avg_min = min(minimum(vehicleBalance),minimum(averageDemand))
# avg_max = max(maximum(averageDemand),maximum(vehicleBalance))

# vehicle_min = minimum(vehicleDemand)
# vehicle_max = maximum(vehicleDemand)

# for h in hours
# for h in 1:nPeriods
#     p1 = heatmap(averageDemand[h,:,:], 
#             c=:viridis,         # color map
#            # clim=(avg_min, avg_max),
#             xlabel="Longitude (grid cols)", 
#             ylabel="Latitude (grid rows)", 
#             title="Average Demand per Grid Cell, hour = $(h)",
#             colorbar_title="Avg Requests")
#             display(p1)
# end

#     p2 = heatmap(vehicleDemand[h,:,:], 
#             c=:viridis,         # color map
#             clim=(vehicle_min, vehicle_max),
#             xlabel="Longitude (grid cols)", 
#             ylabel="Latitude (grid rows)", 
#             title="Vehicle Demand per Grid Cell, hour = $(h)",
#             colorbar_title="Vehicle Demand")
    
#     p = plot(p1,p2, 
#             layout = (1,2),
#             size = (1500,1000),  
#             bottom_margin=5mm,
#             left_margin=12mm, 
#             top_margin=5mm,
#             right_margin=5mm)

#     display(p)
# end

# # Plot for chosen hour 
# p1 = heatmap(vehicleDemand[hour,:,:], 
# c=:viridis,         # color map
# clim=(avg_min, avg_max),
# xlabel="Longitude (grid cols)", 
# ylabel="Latitude (grid rows)", 
# title="Predicted Vehicle Demand",
# colorbar_title="Avg Requests")
# scatter!(p1,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:red)


# p2 = heatmap(activeVehiclesPerCell[hour,:,:], 
# clim=(avg_min, avg_max),
# c=:viridis,         # color map
# xlabel="Longitude (grid cols)", 
# ylabel="Latitude (grid rows)", 
# title="Vehicles per Grid Cell in solution",
# colorbar_title="Vehicle Demand")
# scatter!(p2,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:red)


# p3 = heatmap(vehicleBalance[hour,:,:], 
# c=:viridis,         # color map
# clim=(avg_min, avg_max),
# xlabel="Longitude (grid cols)", 
# ylabel="Latitude (grid rows)", 
# title="Vehicle balance",
# colorbar_title="Vehicle Demand")
# scatter!(p3,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:red)

# super_title = plot(title = "Vehicle Demand Overview - Hour $(hour)", grid=false, framestyle=:none)

# # Combine all into a vertical layout: super title + 3 plots
# p = plot(super_title, plot(p1, p2, p3, layout=(1,3)), layout = @layout([a{0.01h}; b{0.99h}]), size=(1500,1100))


# display(p)
