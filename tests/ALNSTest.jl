using Test 
using alns, domain, utils, offlinesolution

#==
Test ALNSFunctions
==#

@testset "ALNS test - Big Test" begin 
    requestFile = "tests/resources/RequestsBig.csv"
    vehiclesFile = "tests/resources/VehiclesBig.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    scenarioName = "Big"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented
    solution.totalCost += length(scenario.onlineRequests) * scenario.taxiParameter # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.1
    parameters.maxPercentToDestroy = 0.9
    

    # Shaw Destroy 
    shawRemoval!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Regret Repair
    regretInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Random destroy
    randomDestroy!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Worst removal
    worstRemoval!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true
    @test msg == ""
      
end


@testset "ALNS RUN test - Big Test" begin 
    requestFile = "tests/resources/RequestsBig.csv"
    vehiclesFile = "tests/resources/VehiclesBig.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    scenarioName = "Big"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    
    finalSolution, specifications, KPIs = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters)

    feasible, msg = checkSolutionFeasibility(scenario,finalSolution)
    @test feasible == true
    @test msg == ""

    println("FINAL SOLUTION")
    print("nTaxi: ",finalSolution.nTaxi)
    printSolution(finalSolution,printRouteHorizontal)
      
end


@testset "ALNS RUN test - Konsentra Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "Data/Konsentra/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra_withVehicles.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra_withVehicles.txt"
    scenarioName = "Konsentra"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    
    finalSolution,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;initialSolutionConstructor=simpleConstruction)

    feasible, msg = checkSolutionFeasibility(scenario,finalSolution)
    @test feasible == true
    @test msg == ""

    println("FINAL SOLUTION")
    print("nTaxi: ",finalSolution.nTaxi)
    printSolution(finalSolution,printRouteHorizontal)
      
end

