using Test 
using utils 
using offlinesolution
using onlinesolution
using domain
using alns
using CSV


function main()
    # Receive command line arguments 
    n = parse(Int,ARGS[1])
    gamma = parse(Float64,ARGS[2])
    i = parse(Int,ARGS[3])
    gridSize = parse(Int,ARGS[4])
    run = parse(Int,ARGS[5])
    
    displayPlots = false

    # File names 
    vehiclesFile = string("Data/DataWaitingStrategies/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/ParametersShortCallTime.csv"
    outPutFolder = "runfiles/output/Waiting/"*string(n)*"/Run"*string(run)
    gridFile = "Data/Konsentra/grid_$(gridSize).json"
    requestFile = "Data/DataWaitingStrategies/$(n)/GeneratedRequests_$(n)_$(i).csv"
    distanceMatrixFile = string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
    alnsParameters = "tests/resources/ALNSParameters_offline.json"
    scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)    
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)

    println("Running in hindsigt for n: ", n," i: ", i, " run: ", run)
    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    # Get solution
    startSimulation = time()
    initialSolution, requestBankInitial = simpleConstruction(scenario,scenario.requests)
    solution,requestBank,pVals,deltaVals, isImprovedVec,isAcceptedVec,isNewBestVec = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBankInitial,event = scenario.onlineRequests[end],displayPlots=displayPlots,saveResults=false,stage="Offline")
        
    # TODO remove when stable
    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""


    # Save resulsts 
    endSimulation = time()
    totalElapsedTime = endSimulation - startSimulation
    averageResponseTime = 0.0
    eventsInsertedByALNS = 0

    mkpath(outPutFolder)  # ensure folder exists
    fileName = outPutFolder*"/Simulation_KPI_"*string(scenario.name)*"_inhindsight_.json"
    KPIDict = writeOnlineKPIsToFile(fileName,scenario,solution,Vector{Int}(),requestBank,totalElapsedTime,averageResponseTime,eventsInsertedByALNS)
end

main()