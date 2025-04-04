using Test 
using utils 
using simulationframework
using onlinesolution
using domain

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

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
end
