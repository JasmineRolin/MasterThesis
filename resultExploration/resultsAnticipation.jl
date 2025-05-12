using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV






#function main(n::Int, nExpectedPercentage::Float64, gamma::Float64, date::String, resultType::String)

    n = 20
    nExpectedPercentage = 0.1
    gamma = 0.5
    date = "2023-10-01"
    resultType = "BasicAnticipation"

    vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters2.json"
    outPutFolder = string("resultExploration/results/",date,"/",resultType,"/",n)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid.json")

    nExpected = Int(floor(n*nExpectedPercentage))

    for i in 1:10
        requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",i)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")

        # Read scenario 
        #TODO use pre calculated distance and time matrix file. 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)
        solution, requestBank = simulateScenario(scenario,requestFile,distanceMatrixFile,timeMatrixFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,anticipation = true, nExpected=nExpected,printResults = false, saveResults = true,gridFile = gridFile, outPutFileFolder = outPutFolder)

        # TODO remove when stable
        state = State(solution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test feasible == true
        @test msg == ""
    end
    dfResults = processResults(outputFiles)
    CSV.write(outPutFolder*"/results.csv", dfResults)

#end


#==
if abspath(PROGRAM_FILE) == @__FILE__  # Only run if executed directly
    n = parse(Int, ARGS[1])
    nExpectedPercentage = parse(Float64, ARGS[2])
    gamma = parse(Float64, ARGS[3])
    date = ARGS[4]
    resultType = ARGS[5]
    main(n, nExpectedPercentage, gamma, date, resultType)
end
==#