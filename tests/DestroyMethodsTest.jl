using Test
using alns 
using domain 
using utils 
using offlinesolution


# #==
#  Test randomDestroy
# ==#
@testset "randomDestroy test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented
    feasible, msg = checkSolutionFeasibility(scenario,solution)

    # Put two requests in same schedule 
    solution.totalDistance -= solution.vehicleSchedules[3].totalDistance + solution.vehicleSchedules[4].totalDistance
    solution.totalCost -= solution.vehicleSchedules[3].totalCost + solution.vehicleSchedules[4].totalCost
    solution.totalRideTime -= solution.vehicleSchedules[3].totalTime + solution.vehicleSchedules[4].totalTime
    solution.totalIdleTime -= solution.vehicleSchedules[3].totalIdleTime + solution.vehicleSchedules[4].totalIdleTime

    solution.vehicleSchedules[3].numberOfWalking = [solution.vehicleSchedules[3].numberOfWalking[1:4];solution.vehicleSchedules[4].numberOfWalking[2:4];solution.vehicleSchedules[3].numberOfWalking[end]]
    solution.vehicleSchedules[3].numberOfWheelchair = [solution.vehicleSchedules[3].numberOfWheelchair[1:4];solution.vehicleSchedules[4].numberOfWheelchair[2:4];solution.vehicleSchedules[3].numberOfWheelchair[end]]

    solution.vehicleSchedules[3].route = [solution.vehicleSchedules[3].route[1:4];solution.vehicleSchedules[4].route[2:4];solution.vehicleSchedules[3].route[end]]
    solution.vehicleSchedules[3].route[4].endOfServiceTime = 517
    solution.vehicleSchedules[3].route[end-1].endOfServiceTime = 1252


    solution.vehicleSchedules[3].totalCost = getTotalCostRoute(scenario,solution.vehicleSchedules[3].route)
    solution.vehicleSchedules[3].totalDistance = getTotalDistanceRoute(solution.vehicleSchedules[3].route,scenario)
    solution.vehicleSchedules[3].totalTime = getTotalTimeRoute(solution.vehicleSchedules[3])
    solution.vehicleSchedules[3].totalIdleTime = getTotalIdleTimeRoute(solution.vehicleSchedules[3].route)
    

    solution.vehicleSchedules[4] = VehicleSchedule(solution.vehicleSchedules[4].vehicle)

    solution.totalDistance += solution.vehicleSchedules[3].totalDistance 
    solution.totalCost += solution.vehicleSchedules[3].totalCost 
    solution.totalRideTime += solution.vehicleSchedules[3].totalTime 
    solution.totalIdleTime += solution.vehicleSchedules[3].totalIdleTime 

    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true

    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)

    # Destroy 
    randomDestroy!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible1, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 1
    @test length(currentState.assignedRequests) == 2

    randomDestroy!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible2, msg2 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 2
    @test length(currentState.assignedRequests) == 1


    randomDestroy!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible3, msg3 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg3 == ""
    @test feasible3 == true
    @test length(currentState.requestBank) == 3
    @test length(currentState.assignedRequests) == 0
end 


@testset "randomDestroy test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test feasible == true
    @test length(currentState.assignedRequests) == 3

    # Destroy 
    randomDestroy!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible1, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 1
    @test length(currentState.assignedRequests) == 2
end


#==
 Test worstRemoval
==#
@testset "worstRemoval test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented
    feasible, msg = checkSolutionFeasibility(scenario,solution)

    # Put two requests in same schedule 
    solution.totalDistance -= solution.vehicleSchedules[3].totalDistance + solution.vehicleSchedules[4].totalDistance
    solution.totalCost -= solution.vehicleSchedules[3].totalCost + solution.vehicleSchedules[4].totalCost
    solution.totalRideTime -= solution.vehicleSchedules[3].totalTime + solution.vehicleSchedules[4].totalTime
    solution.totalIdleTime -= solution.vehicleSchedules[3].totalIdleTime + solution.vehicleSchedules[4].totalIdleTime

    solution.vehicleSchedules[3].numberOfWalking = [solution.vehicleSchedules[3].numberOfWalking[1:4];solution.vehicleSchedules[4].numberOfWalking[2:4];solution.vehicleSchedules[3].numberOfWalking[end]]
    solution.vehicleSchedules[3].numberOfWheelchair = [solution.vehicleSchedules[3].numberOfWheelchair[1:4];solution.vehicleSchedules[4].numberOfWheelchair[2:4];solution.vehicleSchedules[3].numberOfWheelchair[end]]

    solution.vehicleSchedules[3].route = [solution.vehicleSchedules[3].route[1:4];solution.vehicleSchedules[4].route[2:4];solution.vehicleSchedules[3].route[end]]
    solution.vehicleSchedules[3].route[4].endOfServiceTime = 517
    solution.vehicleSchedules[3].route[end-1].endOfServiceTime = 1252


    solution.vehicleSchedules[3].totalCost = getTotalCostRoute(scenario,solution.vehicleSchedules[3].route)
    solution.vehicleSchedules[3].totalDistance = getTotalDistanceRoute(solution.vehicleSchedules[3].route,scenario)
    solution.vehicleSchedules[3].totalTime = getTotalTimeRoute(solution.vehicleSchedules[3])
    solution.vehicleSchedules[3].totalIdleTime = getTotalIdleTimeRoute(solution.vehicleSchedules[3].route)
    

    solution.vehicleSchedules[4] = VehicleSchedule(solution.vehicleSchedules[4].vehicle)

    solution.totalDistance += solution.vehicleSchedules[3].totalDistance 
    solution.totalCost += solution.vehicleSchedules[3].totalCost 
    solution.totalRideTime += solution.vehicleSchedules[3].totalTime 
    solution.totalIdleTime += solution.vehicleSchedules[3].totalIdleTime 

    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true


    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)

    # Destroy 
    worstRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible1, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 1
    @test length(currentState.assignedRequests) == 2

    worstRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible2, msg2 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 2
    @test length(currentState.assignedRequests) == 1


    worstRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible3, msg3 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg3 == ""
    @test feasible3 == true
    @test length(currentState.requestBank) == 3
    @test length(currentState.assignedRequests) == 0
end 



@testset "worstRemoval test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)

    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test feasible == true
    @test length(currentState.assignedRequests) == 3

    # Destroy 
    worstRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible1, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 1
    @test length(currentState.assignedRequests) == 2
end



# #==
#  Test shawRemoval
# ==#
@testset "shawRemoval test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented
    feasible, msg = checkSolutionFeasibility(scenario,solution)

    # Put two requests in same schedule 
    solution.totalDistance -= solution.vehicleSchedules[3].totalDistance + solution.vehicleSchedules[4].totalDistance
    solution.totalCost -= solution.vehicleSchedules[3].totalCost + solution.vehicleSchedules[4].totalCost
    solution.totalRideTime -= solution.vehicleSchedules[3].totalTime + solution.vehicleSchedules[4].totalTime
    solution.totalIdleTime -= solution.vehicleSchedules[3].totalIdleTime + solution.vehicleSchedules[4].totalIdleTime

    solution.vehicleSchedules[3].numberOfWalking = [solution.vehicleSchedules[3].numberOfWalking[1:4];solution.vehicleSchedules[4].numberOfWalking[2:4];solution.vehicleSchedules[3].numberOfWalking[end]]
    solution.vehicleSchedules[3].numberOfWheelchair = [solution.vehicleSchedules[3].numberOfWheelchair[1:4];solution.vehicleSchedules[4].numberOfWheelchair[2:4];solution.vehicleSchedules[3].numberOfWheelchair[end]]

    solution.vehicleSchedules[3].route = [solution.vehicleSchedules[3].route[1:4];solution.vehicleSchedules[4].route[2:4];solution.vehicleSchedules[3].route[end]]
    solution.vehicleSchedules[3].route[4].endOfServiceTime = 517
    solution.vehicleSchedules[3].route[end-1].endOfServiceTime = 1252


    solution.vehicleSchedules[3].totalCost = getTotalCostRoute(scenario,solution.vehicleSchedules[3].route)
    solution.vehicleSchedules[3].totalDistance = getTotalDistanceRoute(solution.vehicleSchedules[3].route,scenario)
    solution.vehicleSchedules[3].totalTime = getTotalTimeRoute(solution.vehicleSchedules[3])
    solution.vehicleSchedules[3].totalIdleTime = getTotalIdleTimeRoute(solution.vehicleSchedules[3].route)
    

    solution.vehicleSchedules[4] = VehicleSchedule(solution.vehicleSchedules[4].vehicle)

    solution.totalDistance += solution.vehicleSchedules[3].totalDistance 
    solution.totalCost += solution.vehicleSchedules[3].totalCost 
    solution.totalRideTime += solution.vehicleSchedules[3].totalTime 
    solution.totalIdleTime += solution.vehicleSchedules[3].totalIdleTime 

    feasible, msg = checkSolutionFeasibility(scenario,solution)
    @test feasible == true


    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Destroy 
    shawRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 2
    feasible1, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 2
    @test length(currentState.assignedRequests) == 1

    shawRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible2, msg2 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 3
    @test length(currentState.assignedRequests) == 0
end 


@testset "shawRemoval test - Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Constuct solution 
    solution = simpleConstruction(scenario)
    solution.nTaxi += length(scenario.onlineRequests) # TODO: Remove when online request are implemented

    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()
    setMinMaxValuesALNSParameters(parameters,scenario.time,scenario.requests)
    parameters.minPercentToDestroy = 0.7
    parameters.maxPercentToDestroy = 0.7

    # Destroy 
    shawRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 2
    feasible1, msg1 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg1 == ""
    @test feasible1 == true
    @test length(currentState.requestBank) == 2
    @test length(currentState.assignedRequests) == 1

    shawRemoval!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible2, msg2 = checkSolutionFeasibility(scenario,currentState.currentSolution)
    @test msg2 == ""
    @test feasible2 == true
    @test length(currentState.requestBank) == 3
    @test length(currentState.assignedRequests) == 0
end