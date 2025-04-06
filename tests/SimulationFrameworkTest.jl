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

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
end


@testset "test SimulationFramework - Konsentra Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "Data/Konsentra/Vehicles_0.5.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra_Data_NewVehicles.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra_Data_NewVehicles.txt"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"
    scenarioName = "Konsentra"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
 
    # Simulate scenario 
    solution = simulateScenario(scenario)

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
end
