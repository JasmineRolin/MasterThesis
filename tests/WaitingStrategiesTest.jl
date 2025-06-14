
using waitingstrategies, domain, offlinesolution, utils, simulationframework, onlinesolution,alns
using Plots, JSON, Test
using Plots.PlotMeasures

#==
        !!!# OBS OBS OBS OBS OBS #!!!!!

        To run the scenarios with short call time (in Data/WaitingStrategies)
        - change MAX_DELAY = 15 and MAX_EARLY_ARRIVAL = 5 in instance reader 
        - use parameters with short call time (tests/resources/ParametersShortCallTime.csv)
==#

print("\033c")

# Parameters 
n = 20
i = 8
gridSize = 10
displayPlots = true
dynamicProblem = true 
ALNS = true
saveResults = false

gamma = 0.7
nPeriods = 48
maximumTime = 24*60 
periodLength = Int(maximumTime / nPeriods)
nHistoricRequestFiles = 20

alnsParameters = "tests/resources/ALNSParameters_offlineWaiting.json"


true_false = true 
true_true = true
false_false = true


# Retrieve historic request files 
if dynamicProblem
    historicRequestFiles = Vector{String}()
    for j in 1:nHistoricRequestFiles
        push!(historicRequestFiles,"Data/DataWaitingStrategies/HistoricData/$(n)/GeneratedRequests_$(n)_$(j).csv")
    end

    # File names 
    vehiclesFile = string("Data/DataWaitingStrategies/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/ParametersShortCallTime.csv"
    outPutFolder = "runfiles/output/Waiting/Dynamictest/"*string(n)
    gridFile = "Data/Konsentra/grid_$(gridSize).json"
    requestFile = "Data/DataWaitingStrategies/$(n)/GeneratedRequests_$(n)_$(i).csv"
    distanceMatrixFile = string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
    scenarioName = string("Gen_Data_",n,"_",gamma,"_",i)
    maxDelay = 15
    maxEarlyArrival = 5

else 
    historicRequestFiles = Vector{String}()
    for j in 1:nHistoricRequestFiles
        push!(historicRequestFiles,"Data/Konsentra/OriginalInstance/HistoricData/$(n)/GeneratedRequests_$(n)_$(j).csv")
    end

    vehiclesFile = string("Data/Konsentra/OriginalInstance/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    gridFile = "Data/Konsentra/grid_$(gridSize).json"
    requestFile = "Data/Konsentra/OriginalInstance/$(n)/GeneratedRequests_$(n)_$(i).csv"
    distanceMatrixFile = string("Data/Matrices/OriginalInstance/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
    outPutFolder = "runfiles/output/Waiting/Basetest/"*string(n)
    timeMatrixFile =  string("Data/Matrices/OriginalInstance/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
    scenarioName = string("Gen_Data_",n,"_",gamma,"_",i)
    maxDelay = 45 
    maxEarlyArrival = 15
end


scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile,maxDelay=maxDelay,maxEarlyArrival=maxEarlyArrival)

# Read instance 
# for histRequests in historicRequestFiles
#     scenarioName = replace(histRequests, "Data/Konsentra/OriginalInstance/HistoricData/$(n)/GeneratedRequests_$(n)_" => "")
#     histScen = readInstance(histRequests,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile,maxDelay=maxDelay,maxEarlyArrival=maxEarlyArrival)

#     pScen = plotRequestsAndVehiclesWait(histScen,histScen.grid)
#     display(pScen)

#     pGant = createGantChartOfRequestsAndVehicles(histScen.vehicles,histScen.requests,Vector{Int}(),scenarioName)
#     display(pGant)
# end


#savefig(pScen,"tests/WaitingPlots/RequestsAndVehicles_$(n)_$(i)_$(gamma).png")

println("\t nOfflineRequests: ",length(scenario.offlineRequests))


#============================================================================#
# Solve with relocation using common request location probability grid
#============================================================================#
if true_false
    if displayPlots && !isdir("tests/WaitingPlots/"*scenarioName*"/true_false")
        mkpath("tests/WaitingPlots/"*scenarioName*"/true_false")
    end
    if displayPlots && isdir("tests/WaitingPlots/"*scenarioName*"/true_false")
        for file in readdir("tests/WaitingPlots/"*scenarioName*"/true_false"; join=true)
            rm(file; force=true, recursive=true)
        end
    end

    # Simulate scenario 
    solutionTrue, requestBankTrue = simulateScenario(scenario,alnsParameters = alnsParameters,printResults = false,displayPlots = displayPlots,saveResults = saveResults,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=true,nTimePeriods=nPeriods,periodLength=periodLength,scenarioName=scenarioName,relocateWithDemand = false,ALNS=ALNS);

    state = State(solutionTrue,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test msg == ""
    @test feasible == true
    println(msg)
end


#============================================================================#
# Solve with relocation using request demand discretized in grid and time 
#============================================================================#
if true_true 
    if displayPlots && !isdir("tests/WaitingPlots/"*scenarioName*"/true_true")
        mkpath("tests/WaitingPlots/"*scenarioName*"/true_true")
    end
    if displayPlots && isdir("tests/WaitingPlots/"*scenarioName*"/true_true")
        for file in readdir("tests/WaitingPlots/"*scenarioName*"/true_true"; join=true)
            rm(file; force=true, recursive=true)
        end
    end

    # Simulate scenario 
    solutionTrueDemand, requestBankTrueDemand = simulateScenario(scenario,alnsParameters = alnsParameters,printResults = false,displayPlots = displayPlots,saveResults = saveResults,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=true,nTimePeriods=nPeriods,periodLength=periodLength,scenarioName=scenarioName,relocateWithDemand = true);

    state = State(solutionTrueDemand,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test msg == ""
    @test feasible == true
    println(msg)
end


#============================================================================#
# Solve without relocation
#============================================================================#
if false_false
    if displayPlots && !isdir("tests/WaitingPlots/"*scenarioName*"/false_false")
        mkpath("tests/WaitingPlots/"*scenarioName*"/false_false")
    end
    if displayPlots && isdir("tests/WaitingPlots/"*scenarioName*"/false_false")
        for file in readdir("tests/WaitingPlots/"*scenarioName*"/false_false"; join=true)
            rm(file; force=true, recursive=true)
        end
    end

    # Simulate scenario 
    solutionFalse, requestBankFalse = simulateScenario(scenario,alnsParameters = alnsParameters,printResults = false,displayPlots = displayPlots,saveResults = saveResults,saveALNSResults = saveResults, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=false,nTimePeriods=nPeriods,periodLength=periodLength,scenarioName=scenarioName,relocateWithDemand = false);

    state = State(solutionFalse,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test msg == ""
    @test feasible == true
    println(msg)
end

#============================================================================#
# Solve in-hindsigth
#============================================================================#
# alnsParameters = "tests/resources/ALNSParameters_offline.json"

# destroyMethods = Vector{GenericMethod}()
# addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
# addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
# addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

# # Choose repair methods
# repairMethods = Vector{GenericMethod}()
# addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
# addMethod!(repairMethods,"regretInsertion",regretInsertion)

# initialSolution, requestBankALNS = simpleConstruction(scenario,scenario.requests)
# finalSolution,requestBankALNS,pVals,deltaVals, isImprovedVec,isAcceptedVec,isNewBestVec = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBankALNS,event = scenario.onlineRequests[end],displayPlots=displayPlots,saveResults=true,stage="Offline")



#============================================================================#
# Result
#============================================================================#
println("Relocation vehicles TRUE: ", solutionTrue.nTaxi)
println("Relocation vehicles TRUE DEMAND: ", solutionTrueDemand.nTaxi)
println("Relocation vehicles FALSE: ", solutionFalse.nTaxi)
#println("ALNS solution: ", finalSolution.nTaxi)


# #============================================================================#
# # Plots 
# #============================================================================#
# #============================================================================#

# probabilityGrid = getProbabilityGrid(scenario,historicRequestFiles)

# p = heatmap(probabilityGrid, 
# c=:viridis,         # color map
# xlabel="Longitude (grid cols)", 
# ylabel="Latitude (grid rows)", 
# title="Realised Demand",
# colorbar_title="Requests")
# display(p)

#============================================================================#

#==
 Plot time windows of pick ups 
==#
# title = "Pick-Up Time Windows with Call Times for Dynamic Scenario"
# p = plotScenario(scenario.requests,title)

# display(p)
# savefig(p,"plots/Waiting/PickUpTimeWindowsExampleDynamic.png")

# #==
#  Plot time windows for pick up for original problem 
# ==#
# i = 5
# vehiclesFileBase = string("Data/Konsentra/OriginalInstance/",n,"/Vehicles_",n,"_",gamma,".csv")
# parametersFileBase = "tests/resources/Parameters.csv"
# gridFileBase = "Data/Konsentra/grid_$(gridSize).json"
# requestFileBase = "Data/Konsentra/OriginalInstance/$(n)/GeneratedRequests_$(n)_$(i).csv"
# distanceMatrixFileBase = string("Data/Matrices/OriginalInstance/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")

# timeMatrixFileBase =  string("Data/Matrices/OriginalInstance/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
# scenarioNameBase = string("Gen_Data_",n,"_",gamma,"_",i)
# scenarioNameBase = string("Gen_Data_",n,"_",gamma,"_",i)


# # Read instance 
# scenarioBase = readInstance(requestFileBase,vehiclesFileBase,parametersFileBase,scenarioNameBase,distanceMatrixFileBase,timeMatrixFileBase,gridFileBase)
# title = "Pick-Up Time Windows with Call Times for Base Scenario"
# p = plotScenario(scenarioBase.requests,title)

# display(p)
# savefig(p,"plots/Waiting/PickUpTimeWindowsExampleBase.png")


# for r in scenarioBase.requests
#     println("Request $(r.id), request type $(r.requestType)") 
#     println("\t Call time: $(r.callTime)")
#     println("\t Duration from call time to start TW: $(r.pickUpActivity.timeWindow.startTime - r.callTime)")
#     println("\t Duration from call time to end TW: $(r.pickUpActivity.timeWindow.endTime - r.callTime)")
#     println("\t direct drive time: $(r.directDriveTime)")
#     println("\t pick up time window: ($(r.pickUpActivity.timeWindow.startTime) , $(r.pickUpActivity.timeWindow.endTime))")
#     println("\t drop off time window: ($(r.dropOffActivity.timeWindow.startTime) , $(r.dropOffActivity.timeWindow.endTime))")
# end