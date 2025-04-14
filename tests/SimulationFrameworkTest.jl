using Test 
using utils 
using simulationframework
using onlinesolution
using domain

#==
Test SimulationFrameworkUtils
==#
# @testset "test SimulationFramework - Konsentra Test" begin 
#     suff = "Data"
#     requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
#     vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = string("Data/Matrices/Konsentra_",suff,"_distance.txt")
#     timeMatrixFile = string("Data/Matrices/Konsentra_",suff,"_time.txt")
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



# files = ["30.01"]#["Data", "06.02","09.01","16.01","23.01","30.01"]
# suff = files[1]
# for suff in files 
#     println("====> SCENARIO: ",suff)
#     requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
#     vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = string("Data/Matrices/Konsentra_",suff,"_distance.txt")
#     timeMatrixFile = string("Data/Matrices/Konsentra_",suff,"_time.txt")
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



#function main()
    #n = parse(Int,ARGS[1])
    n = 100
    i = 3
    vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters2.json"

    #for i in 1:10
        requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
        scenarioName = string("Konsentra_Data_",n,"_",i)
        
        println("====> SCENARIO: ",scenarioName)

        # Read instance 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
        
        # Read instance 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

        # Simulate scenario 
        solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = false,saveResults = false,saveALNSResults = false, displayALNSPlots = false,outPutFileName= "tests/output/OnlineSimulation/")

        state = State(solution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test feasible == true
        @test msg == ""
    #end
#end

#main()
