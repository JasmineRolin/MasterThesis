using Test 
using utils 
using simulationframework
using onlinesolution
using domain

#==
Test SimulationFrameworkUtils
==#
@testset "test SimulationFramework - Konsentra Test" begin 
    suff = "Data"
    requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
    vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = string("Data/Matrices/Konsentra_",suff,"_distance.txt")
    timeMatrixFile = string("Data/Matrices/Konsentra_",suff,"_time.txt")
    scenarioName = string("Konsentra_",suff)
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
 
    # Simulate scenario 
    solution,requestBank = simulateScenario(scenario)

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
end


# files = ["Data", "06.02","09.01","16.01","23.01","30.01"]
# suff = files[1]
# for suff in files 
#     println("====> SCENARIO: ",suff)
#     requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
#     vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = string("Data/Matrices/Konsentra_",suff,"_distance.txt")
#     timeMatrixFile = string("Data/Matrices/Konsentra_",suff,"_time.txt")
#     scenarioName = string("Konsentra_",suff)
    
#     Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     Simulate scenario 
#     solution = simulateScenario(scenario)

#     state = State(solution,scenario.onlineRequests[end],0)
#     feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#     @test feasible == true
#     @test msg == ""
# end 



