using Test 
using utils 
using offlinesolution
using onlinesolution
using domain
using alns
using CSV






#function main()
    # Receive command line arguments 
    n =20 #parse(Int,ARGS[1])
    gamma =0.7 #parse(Float64,ARGS[2])
    i = 1#parse(Int,ARGS[3])
    gridSize = 10 #parse(Int,ARGS[4])
    run = 1#parse(Int,ARGS[5])
    
    # File names 
    vehiclesFile = string("Data/DataWaitingStrategies/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/ParametersShortCallTime.csv"
    outPutFolder = "runfiles/output/Waiting/"*string(n)*"/Run"*string(run)
    gridFile = "Data/Konsentra/grid_$(gridSize).json"
    requestFile = "Data/DataWaitingStrategies/$(n)/GeneratedRequests_$(n)_$(i).csv"
    distanceMatrixFile = string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/DataWaitingStrategies/",n,"/Matrices/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
    scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)    
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile,gridFile)


    println("Running in hindsigt for n: ", n, " run: ", run)
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
    initialSolution, requestBankALNS = simpleConstruction(scenario,scenario.requests)
    solution,requestBankALNS,pVals,deltaVals, isImprovedVec,isAcceptedVec,isNewBestVec = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBankALNS,event = scenario.onlineRequests[end],displayPlots=displayPlots,saveResults=false,stage="Offline")
        
    # TODO remove when stable
    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""


    # Save resulsts 
    mkpath(outPutFolder)  # ensure folder exists
    fileName = outPutFileFolder*"/Simulation_KPI_"*string(scenario.name)*"_inhindsight_.json"
    KPIDict = writeOnlineKPIsToFile(fileName,scenario,finalSolution,requestBank,requestBankOffline,totalElapsedTime,averageResponseTime,eventsInsertedByALNS)
#end

