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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    @test solution.nTaxi == 0

    # Print solution
    printSolution(solution,printRouteHorizontal)

    # Check solution
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented
    feasible, msg = checkSolutionFeasibility(scenario,solution)
    println(msg)
    @test feasible == true
end

@testset "ConstructionHeurstic test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented
    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true
    @test msg == ""
      
end

@testset "ConstructionHeurstic test - Big Test" begin 
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

    # Print solution
    for vehicle in solution.vehicleSchedules
        printRouteHorizontal(vehicle)
    end

    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true
    @test msg == ""
      
end


