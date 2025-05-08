using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV




n = 100
i = 10
nExpected = floor(n/10)
vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,".csv")
parametersFile = "tests/resources/Parameters.csv"
alnsParameters = "tests/resources/ALNSParameters2.json"
outPutFolder = "tests/output/OnlineSimulation/"*string(n)
outputFiles = Vector{String}()
gridFile = string("Data/Konsentra/grid.json")

#for i in 1:10
    requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
    distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
    scenarioName = string("Gen_Data_",n,"_",i)
    push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")
    
    println("====> SCENARIO: ",scenarioName)


    simulateScenario(scenario; anticipation=true, anticipationParams=(requestFile=requestFile, vehiclesFile=vehiclesFile, parametersFile=parametersFile, alnsParameters=alnsParameters, scenarioName=scenarioName, nExpected=nExpected))

    state = State(solution,scenario.onlineRequests[end],0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
#end
dfResults = processResults(outputFiles)
CSV.write(outPutFolder*"/results.csv", dfResults)