using Test 
using alns, domain, utils, offlinesolution

#==
Test ALNSFunctions
==#
@testset "ALNS test - Big Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Big"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
   
    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.1
    parameters.maxPercentToDestroy = 0.3
    
    printSolution(currentState.currentSolution,printRouteHorizontal)

    # Shaw Destroy 
    shawRemoval!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,scenario.offlineRequests)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Regret Repair
    regretInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,scenario.offlineRequests)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Random destroy
    randomDestroy!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,scenario.offlineRequests)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,scenario.offlineRequests)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Worst removal
    worstRemoval!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,scenario.offlineRequests)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,scenario.offlineRequests)
    if !feasible
        println(msg)
    end
    @test feasible == true
    @test msg == ""
      
end


@testset "ALNS RUN test - Big Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Big"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"

    #Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
   # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    #Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    
    finalSolution, specifications, KPIs = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters)

    feasible, msg = checkSolutionFeasibility(scenario,finalSolution,scenario.offlineRequests)
    @test feasible == true
    @test msg == ""

    println("FINAL SOLUTION")
    print("nTaxi: ",finalSolution.nTaxi)
    printSolution(finalSolution,printRouteHorizontal)
      
end



# @testset "Run all konsentra data sets " begin
#     files = ["Data", "06.02","09.01","16.01","23.01","30.01"]

#     for suff in files 
#         requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
#         vehiclesFile = "Data/Konsentra/Vehicles_0.9.csv"
#         parametersFile = "tests/resources/Parameters.csv"
#         distanceMatrixFile =string("Data/Matrices/Konsentra_",suff,"_distance.txt")
#         timeMatrixFile = string("Data/Matrices/Konsentra_",suff,"_time.txt")
#         scenarioName = string("Konsentra_",suff)
        
#         # Read instance 
#         scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#         # Choose destroy methods
#         destroyMethods = Vector{GenericMethod}()
#         addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
#         addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
#         addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

#         # Choose repair methods
#         repairMethods = Vector{GenericMethod}()
#         addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
#         addMethod!(repairMethods,"regretInsertion",regretInsertion)

        
#         finalSolution,requestBank,specification,KPIs = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;initialSolutionConstructor=simpleConstruction,parametersFile="tests/resources/ALNSParameters2.json",displayPlots=true,savePlots=true)

#         feasible, msg = checkSolutionFeasibility(scenario,finalSolution,scenario.requests)
#         @test feasible == true
#         @test msg == ""
#         println(msg)

#         println("FINAL SOLUTION")
#         print("nTaxi: ",finalSolution.nTaxi)
#         printSolution(finalSolution,printRouteHorizontal)
#     end 
# end


# @testset "Run all generated data sets " begin

#     n = 100
#     vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,".csv")
#     parametersFile = "tests/resources/Parameters.csv"
#     alnsParameters = "tests/resources/ALNSParameters2.json"

#     for i in 1:10
#         requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
#         distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
#         timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
#         scenarioName = string("Konsentra_Data_",n,"_",i)
        
#         # Read instance 
#         scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
        
#         # Choose destroy methods
#         destroyMethods = Vector{GenericMethod}()
#         addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
#         addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
#         addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

#         # Choose repair methods
#         repairMethods = Vector{GenericMethod}()
#         addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
#         addMethod!(repairMethods,"regretInsertion",regretInsertion)
        
#         finalSolution,requestBank,specification,KPIs = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;initialSolutionConstructor=simpleConstruction,parametersFile=alnsParameters,displayPlots=true,savePlots=false)

#         feasible, msg = checkSolutionFeasibility(scenario,finalSolution,scenario.requests)
#         @test feasible == true
#         @test msg == ""
#         println(msg)
#     end
# end
