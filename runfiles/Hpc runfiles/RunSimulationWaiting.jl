
using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV


function main()
    # Receive command line arguments 
    n = parse(Int,ARGS[1])
    gamma = parse(Float64,ARGS[2])
    i = parse(Int,ARGS[3])
    relocateVehicles = parse(Bool,ARGS[4])
    relocateWithDemand = parse(Bool,ARGS[5])
    gridSize = parse(Int,ARGS[6])
    nHistoricRequestFiles = parse(Int,ARGS[7])
    nPeriods = parse(Int,ARGS[8])
    run = parse(Int,ARGS[9])
    baseScenario = parse(Bool,ARGS[10])

    displayPlots = false

    # Find period length 
    maximumTime = 24*60 
    periodLength = Int(maximumTime / nPeriods)


    alnsParameters = "tests/resources/ALNSParameters_offlineWaiting.json"
    gridFile = "Data/Konsentra/grid_$(gridSize).json"
    scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)


    # Retrieve historic request files 
    if !baseScenario 
        historicRequestFiles = Vector{String}()
        for j in 1:nHistoricRequestFiles
            push!(historicRequestFiles,"Data/DataWaitingStrategies/HistoricData/$(n)/GeneratedRequests_$(n)_$(j).csv")
        end

        # File names 
        vehiclesFile = string("Data/DataWaitingStrategies/",n,"/Vehicles_",n,"_",gamma,".csv")
        parametersFile = "tests/resources/ParametersShortCallTime.csv"
        outPutFolder = "runfiles/output/Waiting/DynamicTEST/"*string(n)*"/Run"*string(run)
        requestFile = string("Data/DataWaitingStrategies/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
        
        maxDelay = 15 
        maxEarlyArrival = 5
    else
        historicRequestFiles = Vector{String}()
        for j in 1:nHistoricRequestFiles
            push!(historicRequestFiles,"Data/Konsentra/OriginalInstance/HistoricData/$(n)/GeneratedRequests_$(n)_$(j).csv")
        end

        # File names 
        vehiclesFile = string("Data/Konsentra/OriginalInstance/",n,"/Vehicles_",n,"_",gamma,".csv")
        parametersFile = "tests/resources/Parameters.csv"
        requestFile = "Data/Konsentra/OriginalInstance/$(n)/GeneratedRequests_$(n)_$(i).csv"
        distanceMatrixFile = string("Data/Matrices/OriginalInstance/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
        outPutFolder = "runfiles/output/Waiting/Base/"*string(n)*"/Run"*string(run)
        timeMatrixFile =  string("Data/Matrices/OriginalInstance/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")

        maxDelay = 45 
        maxEarlyArrival = 15
    end

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile,maxDelay=maxDelay,maxEarlyArrival=maxEarlyArrival)

    println("====> SCENARIO: ",scenarioName)
    println("\t Run: ", run)
    println("\t gamma: ",gamma)
    println("\t Relocate vehicles: ",relocateVehicles)
    println("\t Grid size: ",gridSize)
    println("\t Period length: ",periodLength)
    println("\t nOfflineRequests: ",length(scenario.offlineRequests))

    # Simulate scenario 
    solution, requestBank = simulateScenario(scenario,alnsParameters = alnsParameters,printResults = false,displayPlots = displayPlots,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=relocateVehicles,nTimePeriods=nPeriods,periodLength=periodLength,scenarioName=scenarioName,relocateWithDemand=relocateWithDemand);

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    printSolution(solution,printRouteHorizontal)
    @test msg == ""
    @test feasible == true
end

main()
