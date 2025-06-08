using Test 
using utils 
using simulationframework
using onlinesolution
using domain
using CSV
#using alns
#using offlinesolution
#using Plots





function main(n::Int, nExpectedPercentage::Float64, gamma::Float64, date::String, run::String, resultType::String, i::Int)
    vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_offlineAnticipation.json"
    outPutFolder = string("resultExploration/results/",date,"/",resultType,"/",n,"/",run)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid_10.json")

    nExpected = Int(floor(n*nExpectedPercentage))

    #for i in 1:10
        requestFile = string("Data/Konsentra/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",i)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_false.json")

        # Read scenario 
        #TODO use pre calculated distance and time matrix file. 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)
       
        ALNS = true
        displayPlot = true
        keepExpectedRequests = false
        solution, requestBank = simulateScenario(scenario,requestFile,distanceMatrixFile,timeMatrixFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,anticipation = true,nExpected=nExpected,printResults = false, saveResults = false,gridFile = gridFile, outPutFileFolder = outPutFolder, displayPlots = displayPlot,ALNS=ALNS,keepExpectedRequests= keepExpectedRequests)
        

        dfResults = processResults(outputFiles)
        CSV.write(outPutFolder*"/results.csv", dfResults)

        # # Choose destroy methods
        # alnsParameters = "tests/resources/ALNSParameters_offline.json"
        # destroyMethods = Vector{GenericMethod}()
        # addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
        # addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
        # addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

        # # Choose repair methods
        # repairMethods = Vector{GenericMethod}()
        # addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
        # addMethod!(repairMethods,"regretInsertion",regretInsertion)
        # solutionOFF, requestBankOFF = offlineSolution(scenario,repairMethods,destroyMethods,parametersFile,alnsParameters,scenarioName)
        # println("End")

        # display(createGantChartOfSolutionAnticipation(scenario,solutionOFF,"BASE offline solution",scenario.nFixed,requestBankOFF))
    #end
   

end


main(100,0.4,0.5,"2025-06-08","","BasicAnticipation",1)

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
