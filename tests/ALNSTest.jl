using Test 
using alns, domain, utils, offlinesolution

#==
Test ALNSFunctions
==#


@testset "Greedy Repair test" begin

     # Create configuration 
     # Parameters 
     parameters = ALNSParameters()
     configuration = ALNSConfiguration(parameters)


     # Create route
     requestFile = "tests/resources/RequestsRepair.csv"
     vehiclesFile = "tests/resources/Vehicles.csv"
     parametersFile = "tests/resources/Parameters.csv"
     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

     # Read instance 
     scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

     # Create VehicleSchedule
     vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

     # Insert request
     insertRequest!(scenario.requests[1],vehicleSchedule,1,1,WALKING,scenario)

     # Create requestBank
    requestBank = [2]
    assignedRequests = [1]
    nAssignedRequests = 1

    # Solution 
    solution = Solution([vehicleSchedule],70.0,4,5,2,4)

    # Make ALNS state
    state = ALNSState(Float64[2.0,3.5,2.0],Float64[1.0,3.0],[1.0,4.0,1.0],[4.0,1.0],[1,2,1],[2,0],solution,solution,requestBank,assignedRequests,nAssignedRequests)

    # Greedy repair 
    greedyInsertion(state,scenario)

    #printRouteHorizontal(state.currentSolution.vehicleSchedules[1])

    feasible, msg = checkRouteFeasibility(scenario, state.currentSolution.vehicleSchedules[1])
    if !feasible
        println(msg)
    end
    @test feasible == true


end




@testset "Regret Repair test" begin

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)


    # Create route
    requestFile = "tests/resources/RequestsRepair.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    alnsParametersFile = "tests/resources/ALNSParameters.json"

    # Read instance 
    scenario2 = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)
    scenario = Scenario(scenario2.requests,scenario2.onlineRequests,scenario2.offlineRequests,scenario2.serviceTimes,[scenario2.vehicles[1]],scenario2.vehicleCostPrHour,scenario2.vehicleStartUpCost,scenario2.planningPeriod,scenario2.bufferTime,scenario2.maximumDriveTimePercent,scenario2.minimumMaximumDriveTime,scenario2.distance,scenario2.time,scenario2.nDepots,scenario2.depots)

    # Create VehicleSchedule
    vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

    # Insert request
    insertRequest!(scenario.requests[1],vehicleSchedule,1,1,WALKING,scenario)

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    # Create requestBank
    requestBank = [2]
    assignedRequests = [1]
    nAssignedRequests = 1

    # Solution 
    solution = Solution([vehicleSchedule],70.0,4,5,2,4)

    # Make ALNS state
    state = ALNSState(Float64[2.0,3.5,2.0],Float64[1.0,3.0],[1.0,4.0,1.0],[4.0,1.0],[1,2,1],[2,0],solution,solution,requestBank,assignedRequests,nAssignedRequests)

    # Regret repair 
    regretInsertion(state,scenario)

    feasible, msg = checkRouteFeasibility(scenario, state.currentSolution.vehicleSchedules[1])
    @test feasible == true


end

@testset "ALNS test - Big Test" begin 
    requestFile = "tests/resources/RequestsBig.csv"
    vehiclesFile = "tests/resources/VehiclesBig.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Shaw Destroy 
    shawRemoval!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Regret Repair
    regretInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Random destroy
    randomDestroy!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Worst removal
    worstRemoval!(scenario,currentState,parameters)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true

    # Greedy repair
    greedyInsertion(currentState,scenario)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    if !feasible
        println(msg)
    end
    @test feasible == true
    @test msg == ""
      
end


@testset "ALNS RUN test - Big Test" begin 
    requestFile = "tests/resources/RequestsBig.csv"
    vehiclesFile = "tests/resources/VehiclesBig.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)
    
    # Constuct solution 
    solution, requestBank = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0,requestBank)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    
    finalSolution = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods,simpleConstruction,"")

    feasible, msg = checkSolutionFeasibility(scenario,finalSolution)
    @test feasible == true
    @test msg == ""

    println("FINAL SOLUTION")
    print("nTaxi: ",finalSolution.nTaxi)
    printSolution(finalSolution,printRouteHorizontal)
      
end

