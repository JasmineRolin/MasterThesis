
include("../decisionstrategies/anticipation.jl")

#@testset "Anticipation Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"
    scenarioName = "Konsentra_Data"
    
    # Make scenario
    nExpected = 10
    scenario, nFixed, originalExpectedRequestsDf = readInstanceAnticipation(requestFile, DataFrame(), nExpected, vehiclesFile, parametersFile, scenarioName)
    
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
    
    removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,solution,nExpected,nFixed,nNotServicedExpectedRequests,requestBank)
    
    state = State(solution,Request(),nExpected)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state;nExpected=nServicedExpectedRequests)
    @test feasible == true
    @test msg == ""
    
    # Generate new scenario
    nTaxiSolution = copy(solution.nTaxi)
    nExpected = 10
    scenario2, nFixed = readInstanceAnticipation(requestFile, originalExpectedRequestsDf, nExpected, vehiclesFile, parametersFile,scenarioName)
    
    # Insert expected requests randomly into solution using regret insertion
    expectedRequestsIds = collect(nFixed+1:nFixed+nExpected)
    solution.nTaxi = nExpected
    stateALNS = ALNSState(solution,1,1,expectedRequestsIds)
    regretInsertion(stateALNS,scenario2)
    printSolution(solution,printRouteHorizontal)

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario2,state)
    @test msg == ""
    @test feasible == true
    
    
#end