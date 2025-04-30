
using waitingstrategies, domain, offlinesolution, utils
using Plots, JSON, Test
using Plots.PlotMeasures


gamma = 0.9
nData = 10
n = 20 
i = 1
gridFile = "Data/Konsentra/grid.json"
historicIndexes = setdiff(1:nData,i)
hours = 1:24

# List of historic requests 
historicRequestFiles = Vector{String}()
for j in historicIndexes
    push!(historicRequestFiles,"Data/Konsentra/$(n)/GeneratedRequests_$(n)_$(j).csv")
end

# Read grid definition
gridJSON = JSON.parsefile(gridFile) # TODO: jas - i scenario ? 
maxLat = gridJSON["max_latitude"]
minLat = gridJSON["min_latitude"]
maxLong = gridJSON["max_longitude"]
minLong = gridJSON["min_longitude"]
nRows = gridJSON["num_rows"]
nCols = gridJSON["num_columns"]
latStep = (maxLat - minLat) / nRows
longStep = (maxLong - minLong) / nCols

grid = Grid(maxLat,minLat,maxLong,minLong,nRows,nCols,latStep,longStep)


averageDemand = generatePredictedDemand(grid, historicRequestFiles)
vehicleDemand = generatePredictedVehiclesDemand(grid, gamma, averageDemand)

#======================================#
#
#=====================================#
requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
scenarioName = string("Generated_Data_",n,"_",i)
vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",gamma,".csv")
parametersFile = "tests/resources/Parameters.csv"

# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
depotLocations = findDepotLocations(grid)
 
# Construct solution 
initialSolution, requestBank = simpleConstruction(scenario,scenario.requests)
state = State(initialSolution,scenario.onlineRequests[end],0)
feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
@test feasible == true
@test msg == ""
println(msg)

printSolution(initialSolution,printRouteHorizontal)

schedule = solution.vehicleSchedules[7]
waitingActivityCompletedRoute = ActivityAssignment(Activity(schedule.vehicle.depotId,-1,WAITING, schedule.vehicle.depotLocation,TimeWindow(459,720)), schedule.vehicle,459,720)


# Determine waiting location 
location = determineWaitingLocation(depotLocations,grid,vehicleDemand,initialSolution,100)


#==============================#
# Plot 
#==============================#
avg_min = minimum(averageDemand)
avg_max = maximum(averageDemand)

vehicle_min = minimum(vehicleDemand)
vehicle_max = maximum(vehicleDemand)

for h in hours
    p1 = heatmap(averageDemand[h,:,:], 
            c=:viridis,         # color map
            clim=(avg_min, avg_max),
            xlabel="Longitude (grid cols)", 
            ylabel="Latitude (grid rows)", 
            title="Average Demand per Grid Cell, hour = $(h)",
            colorbar_title="Avg Requests")

    p2 = heatmap(vehicleDemand[h,:,:], 
            c=:viridis,         # color map
            clim=(vehicle_min, vehicle_max),
            xlabel="Longitude (grid cols)", 
            ylabel="Latitude (grid rows)", 
            title="Vehicle Demand per Grid Cell, hour = $(h)",
            colorbar_title="Vehicle Demand")
    
    p = plot(p1,p2, 
            layout = (1,2),
            size = (1500,1000),  
            bottom_margin=5mm,
            left_margin=12mm, 
            top_margin=5mm,
            right_margin=5mm)

    display(p)
end
