
using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV


#==
        !!!# OBS OBS OBS OBS OBS #!!!!!

        To run the scenarios with short call time (in Data/WaitingStrategies)
        - change MAX_DELAY = 15 and MAX_EARLY_ARRIVAL = 5 in instance reader 
        - outcomment check for buffer in instance reader in readRequests
                if callTime > requestTime - bufferTime
                    throw(ArgumentError(string("Call time is not before required buffer period for request: ",id)))
                end

==##


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

    # Retrieve historic request files 
    if !baseScenario 
        historicRequestFiles = Vector{String}()
        for j in 1:nHistoricRequestFiles
            push!(historicRequestFiles,"Data/DataWaitingStrategies/HistoricData/$(n)/GeneratedRequests_$(n)_$(j).csv")
        end


        # File names 
        vehiclesFile = string("Data/DataWaitingStrategies/",n,"/Vehicles_",n,"_",gamma,".csv")
        parametersFile = "tests/resources/ParametersShortCallTime.csv"
        outPutFolder = "runfiles/output/Waiting/"*string(n)*"/Run"*string(run)
        gridFile = "Data/Konsentra/grid_$(gridSize).json"

        requestFile = string("Data/DataWaitingStrategies/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)
        
        maxDelay = 15 
        maxEarlyArrival = 5
    else
        historicRequestFiles = Vector{String}()
        for j in 1:nHistoricRequestFiles
            push!(historicRequestFiles,"Data/Konsentra/DoD 40/HistoricData/$(n)/GeneratedRequests_$(n)_$(j).csv")
        end

        # File names 
        vehiclesFile = string("Data/Konsentra/DoD 40/",n,"/Vehicles_",n,"_",gamma,".csv")
        parametersFile = "tests/resources/Parameters.csv"
        gridFile = "Data/Konsentra/grid_$(gridSize).json"
        requestFile = "Data/Konsentra/DoD 40/$(n)/GeneratedRequests_$(n)_$(i).csv"
        distanceMatrixFile = string("Data/Matrices/DoD 40/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
        outPutFolder = "runfiles/output/Waiting/Base/"*string(n)

        timeMatrixFile =  string("Data/Matrices/DoD 40/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)
        
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
    solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = displayPlots,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder,historicRequestFiles=historicRequestFiles, gamma=gamma,relocateVehicles=relocateVehicles,nTimePeriods=nPeriods,periodLength=periodLength,scenarioName=scenarioName,relocateWithDemand=relocateWithDemand);

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    printSolution(solution,printRouteHorizontal)
    @test msg == ""
    @test feasible == true
end

main()
