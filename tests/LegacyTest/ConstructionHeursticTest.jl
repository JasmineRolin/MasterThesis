using Test 

using utils, domain, offlinesolution

#==
 Test ConstructionHeuristicTest 
==#
@testset "ConstructionHeuristicTest test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
    @test solution.nTaxi == 0

    # Print solution
    printSolution(solution,printRouteHorizontal)

    # Check solution
    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    println(msg)
    @test feasible == true
end

@testset "ConstructionHeurstic test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Big"
    
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
  
    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
end

@testset "ConstructionHeurstic test - Big Test" begin 
    requestFile = "tests/resources/RequestsBig.csv"
    vehiclesFile = "tests/resources/VehiclesBig.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/Big_distance.txt"
    timeMatrixFile = "tests/resources/Big_time.txt"
    scenarioName = "Konsentra"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
      
end


