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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution = simpleConstruction(scenario)

    # Add online requests to taxies 
    # TODO: remove when online solution is created 
    solution.nTaxi += length(scenario.onlineRequests)

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true
end

@testset "checkSolutionFeasibility test - infeasible cost" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution = simpleConstruction(scenario)
    solution.totalCost = 90.0

    # Add online requests to taxies 
    # TODO: remove when online solution is created 
    solution.nTaxi += length(scenario.onlineRequests)

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Total cost of solution is incorrect. Calculated: 109500.0, actual: 90.0"
end

@testset "checkSolutionFeasibility test - activity serviced multiple times" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution = simpleConstruction(scenario)
    insertRequest!(scenario.requests[3],solution.vehicleSchedules[1],1,1,WALKING,scenario)

    # Add online requests to taxies 
    # TODO: remove when online solution is created 
    solution.nTaxi += length(scenario.onlineRequests)

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Activity 8 is serviced more than once"
end


@testset "checkSolutionFeasibility test - activity not serviced" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution = simpleConstruction(scenario)

    # Add online requests to taxies 
    # TODO: remove when online solution is created 
    solution.nTaxi += length(scenario.onlineRequests) - 1

    # Check solution
    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Not all activities are serviced"
end