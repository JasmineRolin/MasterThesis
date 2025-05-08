
using waitingstrategies, domain, offlinesolution, utils, simulationframework
using Plots, JSON, Test
using Plots.PlotMeasures

print("\033c")

# Er der for mange ved hvert depot ???? 
# Gør så der bliver valgt ud fra en vægt af demand ? 

gamma = 0.9
nData = 10
n = 20 
i = 7
gridFile = "Data/Konsentra/grid.json"
historicIndexes = setdiff(1:nData,i)
nPeriods = 24
maximumTime = 24*60 
periodLength = Int(maximumTime / nPeriods)

# List of historic requests 
historicRequestFiles = Vector{String}()
for j in historicIndexes
    push!(historicRequestFiles,"Data/Konsentra/$(n)/GeneratedRequests_$(n)_$(j).csv")
end

requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
scenarioName = string("Generated_Data_",n,"_",i)
vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",gamma,".csv")
parametersFile = "tests/resources/Parameters.csv"

# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)

outPutFolder = "tests/output/OnlineSimulation/"*string(n)

relocateVehicles = false
solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = true,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=relocateVehicles,nTimePeriods=nPeriods,periodLength=periodLength);

state = State(solution,scenario.onlineRequests[end],0)
feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
@test feasible == true
@test msg == ""
println(msg)

print("end")

# Event 20 veh 2



# initialSolution, requestBank = simpleConstruction(scenario,scenario.requests)
# display(createGantChartOfSolutionOnline(initialSolution,"Final Solution after merge"))

schedule = deepcopy(solution.vehicleSchedules[2])
request = scenario.requests[20]
posPU = 4
posDO = 4
feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd =
 checkFeasibilityOfInsertionAtPosition(request,schedule,posPU,posDO,scenario)

 const EMPTY_RESULT = (false, -1, -1, Vector{Int}(), Vector{Int}(), Vector{Int}(), typemax(Float64), typemax(Float64), typemax(Int), typemax(Int), Vector{Int}())

# TODO: delete 
global countTotal = Ref(0)
global countFeasible = Ref(0)

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


# averageDemand = generatePredictedDemand(grid, historicRequestFiles,nPeriods,periodLength)
# vehicleDemand = generatePredictedVehiclesDemand(grid, gamma, averageDemand)

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
