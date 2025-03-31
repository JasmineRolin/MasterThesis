using Test 
using utils 
using simulationframework


#==
# Test SimulationFrameworkUtils
==#
#@testset "test SimulationFrameworkUtils" begin 
    # requestFile = "tests/resources/RequestsToTestSimulation.csv"
    # vehiclesFile = "tests/resources/Vehicles.csv"
    # parametersFile = "tests/resources/Parameters.csv"
    # distanceMatrixFile = "tests/resources/distanceMatrix_SmallToTestSimulation.txt"
    # timeMatrixFile = "tests/resources/timeMatrix_SmallToTestSimulation.txt"
    # scenarioName = "SmallToTestSimulation."

    suff =  "30.01" #"06.02"#,"09.01","16.01","23.01","30.01"]

    requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
    vehiclesFile = "Data/Konsentra/Vehicles_0.5.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = string("Data/Matrices/distanceMatrix_Konsentra_Data_",suff,".txt")
    timeMatrixFile = string("Data/Matrices/timeMatrix_Konsentra_Data_",suff,".txt")
    scenarioName = string("Konsentra_",suff)
  

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Simulate scenario
    solution = simulateScenario(scenario)
    
    feasible, msg = checkSolutionFeasibility(scenario,solution,scenario.offlineRequests)

    @test feasible == true
    @test msg == ""
#end
