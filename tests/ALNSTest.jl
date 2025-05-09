using Test 
using alns, domain, utils, offlinesolution, TimerOutputs

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

    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Regret Repair
    regretInsertion(currentState,scenario)

    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Random destroy
    randomDestroy!(scenario,currentState,parameters)

    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Worst removal
    worstRemoval!(scenario,currentState,parameters)

    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    state = State(currentState.currentSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println(msg)
    end
    @test feasible == true
    @test msg == ""
      
end


#==
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

  
    initialSolution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    displayPlots = false
    finalSolution, requestBank = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank,displayPlots = displayPlots)

    state = State(finalSolution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""

    println("FINAL SOLUTION")
    print("nTaxi: ",finalSolution.nTaxi)
    printSolution(finalSolution,printRouteHorizontal)
      
end
==#


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

#         initialSolution, requestBank = simpleConstruction(scenario,scenario.requests)
#         finalSolution, requestBank = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters2.json",initialSolution=initialSolution,requestBank=requestBank)
        
#         state = State(finalSolution,scenario.onlineRequests[end],0)
#         feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#         @test feasible == true
#         @test msg == ""
#         println(msg)

#         feasible, msg = checkSolutionFeasibility(scenario,finalSolution,scenario.requests)
#         @test feasible == true
#         @test msg == ""
#         println(msg)

#         println("FINAL SOLUTION")
#         print("nTaxi: ",finalSolution.nTaxi)
#         printSolution(finalSolution,printRouteHorizontal)
#     end 
# end



# # #@testset "Run all generated data sets " begin

#     # Number of requests in scenario - 20, 100, 300 or 500 
#     n = 500

# #     # Scenario number - 1:10
#     i = 1

#     # Files 
#     gamma = 0.5
#     vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",gamma,".csv")
#     parametersFile = "tests/resources/Parameters.csv"
#     alnsParameters = "tests/resources/ALNSParameters3.json"

#     # Set both true to see plots 
#     displayPlots = false
#     saveResults = false

#     #for i in 1:10
#         requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
#         distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_distance.txt")
#         timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",gamma,"_",i,"_time.txt")
#         scenarioName = string("Generated_Data_",n,"_",i)
        
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
        
#         TO = TimerOutput()
#         initialSolution, requestBank = simpleConstruction(scenario,scenario.requests,TO=TO)
#         finalSolution,requestBank,pVals,deltaVals, isImprovedVec,isAcceptedVec,isNewBestVec = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank,event = scenario.onlineRequests[end],displayPlots=displayPlots,saveResults=saveResults,stage="Offline")

#         state = State(finalSolution,scenario.onlineRequests[end],0)
#         feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
#         @test feasible == true
#         @test msg == ""
#         println(msg)

#         println(rpad("Metric", 40), "Value")
#         println("-"^45)
#         println(rpad("Final nTaxi", 40), finalSolution.nTaxi)
#         println(rpad("Final cost", 40), finalSolution.totalCost)
#         println(rpad("Final distance", 40), finalSolution.totalDistance)
#         println(rpad("Final ride time (veh)", 40), finalSolution.totalRideTime)
#         println(rpad("Final idle time", 40), finalSolution.totalIdleTime)
#    # end
    
# # #end

# # # using Plots
# # # p1 = plot(pVals, title="p-values", label="p-values", xlabel="iteration", ylabel="p-value",size = (1500,1000))
# # # p2 = plot(deltaVals, title="delta", label="delta", xlabel="iteration", ylabel="delta",size = (1500,1000))
# # # display(p1)
# # # display(p2)


# # # onlyAccepted = isAcceptedVec .& .!isNewBestVec .& .!isImprovedVec
# # # it = collect(1:length(isAcceptedVec))[onlyAccepted]
# # # p2 = plot(it,deltaVals[onlyAccepted], title="delta", label="delta", xlabel="iteration", ylabel="delta",size = (1500,1000))
