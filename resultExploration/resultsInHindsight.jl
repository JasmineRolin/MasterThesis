using Test 
using utils 
using offlinesolution
using domain
using alns
using CSV






function main(n::Int, nExpectedPercentage::Float64, gamma::Float64, date::String, run::String, resultType::String, i::Int)
    saveResults = true
    dataset = "OriginalInstance"
    vehiclesFile = string("Data/Konsentra/",dataset,"/",n,"/Vehicles_",n,"_",gamma,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_InHindsight.json"
    outPutFolder = string("resultExploration/results/",date,"/",resultType,"/",n,"/",run)
    outputFiles = Vector{String}()
    gridFile = string("Data/Konsentra/grid_10.json")

    #for i in 1:10
        requestFile = string("Data/Konsentra/",dataset,"/",n,"/GeneratedRequests_",n,"_",i,".csv")
        distanceMatrixFile = string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
        timeMatrixFile =  string("Data/Matrices/",dataset,"/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
        scenarioName = string("Gen_Data_",n,"_",i)
        push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_false.json")

        # Read scenario 
        #TODO use pre calculated distance and time matrix file. 
        scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,"","",gridFile)

        # Choose destroy methods
        destroyMethods = Vector{GenericMethod}()
        addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
        addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
        addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

        # Choose repair methods
        repairMethods = Vector{GenericMethod}()
        addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
        addMethod!(repairMethods,"regretInsertion",regretInsertion)

        # Get solution
        solution, requestBank, ALNSIterations = inHindsightSolution(scenario,repairMethods,destroyMethods,parametersFile,alnsParameters,scenarioName,displayPlots=true)
        println(requestBank)

        if saveResults
            mkpath(outPutFolder)  # ensure folder exists
            fileName = outPutFolder * "/Simulation_KPI_" * string(scenario.name) * "_false.txt"
        
            open(fileName, "w") do io
                println(io, "Dataset: $i, TotalCost: $(solution.totalCost), UnservedRequests: $(length(requestBank)), ALNSIterations: $(ALNSIterations)")
            end
        end


        # TODO remove when stable
        state = State(solution,scenario.onlineRequests[end],0)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        @test feasible == true
        @test msg == ""
    #end
    #dfResults = processResults(outputFiles)
    #CSV.write(outPutFolder*"/results.csv", dfResults)

end

#main(300,0.5,0.5,"2025-06-01_test","","InHindsight",1)

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
