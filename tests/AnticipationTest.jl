
include("../decisionstrategies/anticipation.jl")

#==
#@testset "Anticipation Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"
    scenarioName = "Konsentra_Data"
    
    # Make scenario
    nExpected = 10
    scenario = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile, scenarioName)
    nFixed = scenario.nFixed

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
    solution, requestBank,_,_, _,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank)
    
    # Save original solution
    originalSolution = copySolution(solution)
    originalRequestBank = copy(requestBank)
    nTaxiSolution = copy(solution.nTaxi)

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
    
    
    # Determine number of serviced requests
    nNotServicedFixedRequests = sum(requestBank .<= nFixed)
    nNotServicedExpectedRequests = sum(requestBank .> nFixed)
    nServicedFixedRequests = nFixed - nNotServicedFixedRequests
    nServicedExpectedRequests = nExpected - nNotServicedExpectedRequests
    
    
    time = scenario.time
    distance = scenario.distance
    serviceTimes = scenario.serviceTimes
    requests = scenario.requests
    taxiParameterExpected = scenario.taxiParameterExpected
    
    removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,solution,nExpected,nFixed,nNotServicedExpectedRequests,requestBank,taxiParameterExpected)
    
    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=nExpected)
    @test msg == ""
    @test feasible == true
    
    
    # Generate new scenario
    nExpected = 10
    scenario2 = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName)
    
    # Insert expected requests randomly into solution using regret insertion
    expectedRequestsIds = collect(nFixed+1:nFixed+nExpected)
    solution.nTaxi = nExpected
    solution.totalCost += nExpected * scenario.taxiParameterExpected
    stateALNS = ALNSState(solution,1,1,expectedRequestsIds)
    regretInsertion(stateALNS,scenario2)

    state = State(solution,Request(),nNotServicedFixedRequests)
    feasible, msg = checkSolutionFeasibilityOnline(scenario2,state)
    @test msg == ""
    @test feasible == true
    
    
#end
==#


#@testset "Complete Anticipation Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"
    scenarioName = "Konsentra_Data"
    
    nExpected = 10
    bestSolution, bestRequestBank, results, scenario, scenario2,feasible, msg = offlineSolutionWithAnticipation(requestFile,vehiclesFile,parametersFile,alnsParameters,scenarioName,nExpected)

    println(results)

    #state = State(solution,Request(),0)
    #feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    #@test msg == ""
    #@test feasible == true
    
#end
