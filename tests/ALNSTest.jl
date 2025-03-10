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
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    solution0 = deepcopy(solution)

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)
    solution1 = deepcopy(currentState.currentSolution)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Shaw Destroy 
    shawRemoval!(scenario,currentState,parameters)
    solution2 = deepcopy(currentState.currentSolution)

    feasible, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg1)
    end
    @test feasible == true

    # Regret Repair
    regretInsertion(currentState,scenario)
    solution3 = deepcopy(currentState.currentSolution)
    feasible, msg2 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg2)
    end
    @test feasible == true

    # Random destroy
    randomDestroy!(scenario,currentState,parameters)
    solution4 = deepcopy(currentState.currentSolution)
    feasible, msg3 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg3)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)
    solution5 = deepcopy(currentState.currentSolution)
    feasible, msg4 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg4)
    end
    @test feasible == true

    # Worst removal
    worstRemoval!(scenario,currentState,parameters)
    solution6 = deepcopy(currentState.currentSolution)
    feasible, msg5 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg5)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)
    solution7 = deepcopy(currentState.currentSolution)
    feasible, msg6 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg6)
    end
    @test feasible == true      
end


@testset "ALNS RUN test - Big Test" begin 
    requestFile = "tests/resources/RequestsBig.csv"
    vehiclesFile = "tests/resources/VehiclesBig.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    
    finalSolution = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods,simpleConstruction,"")

    feasible, msg = checkSolutionFeasibility(scenario,finalSolution)
    @test feasible == true
    @test msg == ""

    println("FINAL SOLUTION")
    print("nTaxi: ",finalSolution.nTaxi)
    printSolution(finalSolution,printRouteHorizontal)
      
end

