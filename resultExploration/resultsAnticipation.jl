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
    outPutFolder = string("resultExploration/results/",date,"/",run,"/",resultType,"/",n)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid.json")

    nExpected = Int(floor(n*nExpectedPercentage))

    #for i in 1:10
        requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",i)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_false.json")

        # Read scenario 
        #TODO use pre calculated distance and time matrix file. 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)
       
        ALNS = true
        displayPlot = false
        solution, requestBank = simulateScenario(scenario,requestFile,distanceMatrixFile,timeMatrixFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,anticipation = true,nExpected=nExpected,printResults = false, saveResults = true,gridFile = gridFile, outPutFileFolder = outPutFolder, displayPlots = displayPlot,ALNS=ALNS)
        
        # TODO remove when stable
        state = State(solution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test feasible == true
        @test msg == ""

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


#main(300,0.3,0.5,"2025-05-18","","BasicAnticipation",1)

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
