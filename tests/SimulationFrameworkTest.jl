using Test 
using utils 
using simulationframework


#==
# Test SimulationFrameworkUtils
==#
@testset "test SimulationFrameworkUtils" begin 
    requestFile = "tests/resources/RequestsToTestSimulation.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_SmallToTestSimulation.txt"
    timeMatrixFile = "tests/resources/timeMatrix_SmallToTestSimulation.txt"
    scenarioName = "SmallToTestSimulation."

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Simulate scenario 
    solution = simulateScenario(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # Remove when online request are implemented
    solution.totalCost += length(scenario.onlineRequests) * scenario.taxiParameter # TODO: Remove when online request are implemented

    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true
    @test msg == ""
end
