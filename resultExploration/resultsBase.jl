using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV






function main(n::Int, nExpectedPercentage::Float64, gamma::Float64, date::String, run::String, resultType::String, i::Int)

    dataset = "Original"
    vehiclesFile = string("Data/Konsentra/",dataset,"/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/ParametersShortCallTime2.csv"
    alnsParameters = "tests/resources/ALNSParameters_offline.json"
    outPutFolder = string("resultExploration/results/",date,"/",resultType,"/",n,"/",run)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid.json")

    #for i in 1:10
        requestFile = string("Data/Konsentra/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",i)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_false.json")

        # Read scenario 
        #TODO use pre calculated distance and time matrix file. 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)
        solution, requestBank = simulateScenario(scenario,requestFile,distanceMatrixFile,timeMatrixFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,anticipation = false,printResults = false, saveResults = true,gridFile = gridFile, outPutFileFolder = outPutFolder, displayPlots = true)
        println("requestBank: ", requestBank)

        # TODO remove when stable
        state = State(solution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test feasible == true
        @test msg == ""
    #end
    #dfResults = processResults(outputFiles)
    #CSV.write(outPutFolder*"/results.csv", dfResults)

end

#main(50,0.5,0.7,"2025-05-23","","BaseCase",1)

if abspath(PROGRAM_FILE) == @__FILE__
    n = parse(Int, ARGS[1])
    nExpectedPercentage = parse(Float64, ARGS[2])
    gamma = parse(Float64, ARGS[3])
    date = ARGS[4]
    run = ARGS[5]
    resultType = ARGS[6]
    dataset = parse(Int, ARGS[7])
    main(n, nExpectedPercentage, gamma, date, run, resultType, dataset)
end
