using Test

using utils, domain, offlinesolution

#==
# Test checkSolutionFeasibility
==#
@testset "checkSolutionFeasibility test - feasible solution" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution,scenario.offlineRequests)
    @test feasible == true
end

@testset "checkSolutionFeasibility test - infeasible cost" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
    solution.totalCost = 90.0

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution,scenario.offlineRequests)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Total cost of solution is incorrect. Calculated: 30.0, actual: 90.0"
end


@testset "checkSolutionFeasibility test - activity not serviced" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution,scenario.requests)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Not all activities are serviced. Serviced: 6, not serviced: 4, nTaxi: 0"
end