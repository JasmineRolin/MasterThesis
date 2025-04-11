using Test
using alns 
using domain 
using utils 
using offlinesolution


# #==
#  Test randomDestroy
# ==#
@testset "randomDestroy test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.requests)

    # Check Solution 
    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true

    # Construct ALNS state
    currentState = ALNSState(solution,solution.nTaxi,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    parameters.minPercentToDestroy = 0.1
    parameters.maxPercentToDestroy = 0.1
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)

    # Destroy 
    randomDestroy!(scenario,currentState,parameters)

    # Check Solution 
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible1, msg1 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 2
    @test length(currentState.assignedRequests) == 3

    # Destroy
    randomDestroy!(scenario,currentState,parameters)

    # Check Solution 
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible2, msg2 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 3
    @test length(currentState.assignedRequests) == 2


    randomDestroy!(scenario,currentState,parameters)
    # Check Solution 
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible3, msg3 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg3 == ""
    @test feasible3 == true
    @test length(currentState.requestBank) == 4
    @test length(currentState.assignedRequests) == 1

    randomDestroy!(scenario,currentState,parameters)
    # Check Solution 
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible3, msg3 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg3 == ""
    @test feasible3 == true
    @test length(currentState.requestBank) == 5
    @test length(currentState.assignedRequests) == 0

end 


@testset "randomDestroy test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Konsentra"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Check Solution 
    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test length(currentState.assignedRequests) == 8

    # Destroy 
    randomDestroy!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,Request(),0)
    feasible1, msg1 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 15
    @test length(currentState.assignedRequests) == 2
end


#==
 Test worstRemoval
==#
@testset "worstRemoval test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.requests)
   
    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Destroy 
    worstRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible1, msg1 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 4
    @test length(currentState.assignedRequests) == 1

    # Destroy 
    worstRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible2, msg2 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 5
    @test length(currentState.assignedRequests) == 0
end 



@testset "worstRemoval test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Konsentra"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test length(currentState.assignedRequests) == 8

    printSolution(currentState.currentSolution,printRouteHorizontal)

    # Destroy 
    worstRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,Request(),0)
    feasible1, msg1 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 15
    @test length(currentState.assignedRequests) == 2
end



# #==
#  Test shawRemoval
# ==#
@testset "shawRemoval test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.requests)

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true


    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Destroy 
    shawRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible1, msg1 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 4
    @test length(currentState.assignedRequests) == 1

    shawRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,scenario.onlineRequests[end],0)
    feasible2, msg2 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 5
    @test length(currentState.assignedRequests) == 0
end 


@testset "shawRemoval test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Konsentra"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Destroy 
    shawRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,Request(),0)
    feasible1, msg1 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 15
    @test length(currentState.assignedRequests) == 2

    shawRemoval!(scenario,currentState,parameters)
    state = State(currentState.currentSolution,Request(),0)
    feasible2, msg2 = checkSolutionFeasibilityOnline(scenario,state)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 16
    @test length(currentState.assignedRequests) == 1
end