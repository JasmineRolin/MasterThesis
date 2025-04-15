
using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV

#== 
 Generated data 
==# 
# function main()
#     n = parse(Int,ARGS[1])
#    # n = 20
#     #i = 9
#     vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,".csv")
#     parametersFile = "tests/resources/Parameters.csv"
#     alnsParameters = "tests/resources/ALNSParameters2.json"
#     outPutFolder = "runfiles/output/OnlineSimulation/"*string(n)
#     outputFiles = Vector{String}()

#     for i in 1:10
#         requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
#         distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
#         timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
#         scenarioName = string("Gen_Data_",n,"_",i)
#         push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")
        
#         println("====> SCENARIO: ",scenarioName)

#         # Read instance 
#         scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
#         # Simulate scenario 
#         solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = false,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder)

#         state = State(solution,scenario.onlineRequests[end],0)
#         feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#         @test feasible == true
#         @test msg == ""
#    end

#     dfResults = processResults(outputFiles)
#     CSV.write(outPutFolder*"/results.csv", dfResults)

# end

#== 
 Konsentra data 
==# 
function main()
    files = ["Data", "06.02","09.01","16.01","23.01","30.01"]

    vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
    parametersFile = "tests/resources/Parameters.csv"
    outPutFolder = "runfiles/output/OnlineSimulation/Konsentra"
    outputFiles = Vector{String}()

    for suff in files 
        requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
        distanceMatrixFile = string("Data/Matrices/Konsentra_",suff,"_distance.txt")
        timeMatrixFile = string("Data/Matrices/Konsentra_",suff,"_time.txt")
        scenarioName = string("Konsentra_",suff)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")
        
        println("====> SCENARIO: ",scenarioName)

        # Read instance 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
        # Simulate scenario 
        solution, requestBank = simulateScenario(scenario,printResults = false,displayPlots = false,saveResults = true,saveALNSResults = false, displayALNSPlots = false, outPutFileFolder= outPutFolder)

        state = State(solution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test feasible == true
        @test msg == ""
   end

    dfResults = processResults(outputFiles)
    CSV.write(outPutFolder*"/results.csv", dfResults)
end

main()
