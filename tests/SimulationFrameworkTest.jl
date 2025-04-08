using Test 
using utils 
using simulationframework
using onlinesolution
using domain

#==
# Test SimulationFrameworkUtils
==#
# @testset "test SimulationFrameworkUtils" begin 
#     requestFile = "tests/resources/RequestsToTestSimulation.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_SmallToTestSimulation.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_SmallToTestSimulation.txt"
#     scenarioName = "SmallToTestSimulation."

#     suff =  "30.01" #"06.02"#,"09.01","16.01","23.01","30.01"]

#     requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
#     vehiclesFile = "Data/Konsentra/Vehicles_0.5.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = string("Data/Matrices/distanceMatrix_Konsentra_Data_",suff,".txt")
#     timeMatrixFile = string("Data/Matrices/timeMatrix_Konsentra_Data_",suff,".txt")
#     scenarioName = string("Konsentra_",suff)
  

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Simulate scenario
#     solution = simulateScenario(scenario)

#     state = State(solution,scenario.onlineRequests[end],0)
#     feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#     @test feasible == true
#     @test msg == ""
# end


# @testset "test SimulationFramework - Konsentra Test" begin 
#     requestFile = "Data/Konsentra/TransformedData_Data.csv"
#     vehiclesFile = "Data/Konsentra/Vehicles_0.5.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra_Data_NewVehicles.txt"
#     timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra_Data_NewVehicles.txt"
#     alnsParameters = "tests/resources/ALNSParameters_Article.json"
#     scenarioName = "Konsentra"
    
#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
 
#     # Simulate scenario 
#     solution = simulateScenario(scenario)

#     state = State(solution,scenario.onlineRequests[end],0)
#     feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#     @test feasible == true
#     @test msg == ""
# end


#==
@testset "Run all konsentra data sets " begin
    
end
==#

files = [ "06.02"]#, "Data", "06.02","09.01","16.01","23.01","30.01"]
suff = files[1]
#for suff in files 
    requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
    vehiclesFile = "Data/Konsentra/Vehicles_0.5.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = string("Data/Matrices/distanceMatrix_Konsentra_Data_",suff,".txt")
    timeMatrixFile = string("Data/Matrices/timeMatrix_Konsentra_Data_",suff,".txt")
    scenarioName = string("Konsentra_",suff)
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Simulate scenario 
    state = simulateScenario(scenario)

   # state = State(solution,scenario.onlineRequests[end],0)
#     feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#     @test feasible == true
#     @test msg == ""
# end 


#getTotalCostRouteOnline(scenario.time,solution.vehicleSchedules[14].route,state.visitedRoute,2)