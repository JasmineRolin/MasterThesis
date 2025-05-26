using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV





 
function main(n::Int, nExpectedPercentage::Float64, gamma::Float64, date::String, run::String, resultType::String, i::Int)

#n = 20 
#nExpectedPercentage = 0.4
#gamma = 0.5
#date = "2025-05-23"
#run = ""
#resultType = "AnticipationKeepExpected"
#i = 1

    dataset = "DoD 60 Calltime60-120"
    vehiclesFile = string("Data/Konsentra/",dataset,"/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/ParametersShortCallTime2.csv"
    alnsParameters = "tests/resources/ALNSParameters_offlineAnticipation.json"
    outPutFolder = string("resultExploration/results/",date,"/",run,"/",resultType,"/",n)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid.json")

    nExpected = Int(floor(n*nExpectedPercentage))

    #for i in 1:10
        requestFile = string("Data/Konsentra/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",i)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_false.json")

        # Read scenario 
        #TODO use pre calculated distance and time matrix file. 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)
        solution, requestBank = simulateScenario(scenario,requestFile,distanceMatrixFile,timeMatrixFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,anticipation = true,nExpected=nExpected,printResults = false, saveResults = true,gridFile = gridFile, outPutFileFolder = outPutFolder, displayPlots = true, keepExpectedRequests = true)
    #end
    #dfResults = processResults(outputFiles)
    #CSV.write(outPutFolder*"/results.csv", dfResults)

end

#main(50,0.6,0.7,"2025-05-23","","AnticipationKeepExpected",1)

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
