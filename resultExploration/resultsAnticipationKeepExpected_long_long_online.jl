using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV





 
function main(n::Int, nExpectedPercentage::Float64, gamma::Float64, date::String, run::String, resultType::String, i::Int)

    dataset = "OriginalInstance"
    vehiclesFile = string("Data/Konsentra/",dataset,"/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_offlineAnticipation_long.json"
    ALNSparametersOnline = "tests/resources/ALNSParameters_online_long.json"
    outPutFolder = string("resultExploration/results/",date,"/",resultType,"/",n,"/",run)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid_10.json")

    nExpected = Int(floor(n*nExpectedPercentage))
    
    useAnticipationOnlineRequests = true
    anticipation = true
    keepExpectedRequests = true
    splitRequestBank = true
    
    printResults = false
    saveResults = true
    displayPlots = false



    requestFile = string("Data/Konsentra/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,".csv")
    distanceMatrixFile = string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
    scenarioName = string("Gen_Data_",n,"_",i)
    push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_false.json")

    # Read scenario 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)
    solution, requestBank = simulateScenario(scenario,requestFile,distanceMatrixFile,timeMatrixFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,anticipation = anticipation,nExpected=nExpected,printResults = printResults, saveResults = saveResults,gridFile = gridFile, outPutFileFolder = outPutFolder, displayPlots = displayPlots, keepExpectedRequests = keepExpectedRequests, useAnticipationOnlineRequests = useAnticipationOnlineRequests, splitRequestBank = splitRequestBank, ALNSparametersOnline = ALNSparametersOnline)


end

#main(20,0.4,0.5,"2025-06-18_Test","","AnticipationKeep",2)

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
