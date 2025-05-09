using Test

using utils, domain, offlinesolution

#==
# Test checkSolutionFeasibility
==#
@testset "checkSolutionFeasibility test - feasible solution" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)

    # Check solution
    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
end

@testset "checkSolutionFeasibility test - infeasible cost" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
    solution.totalCost = 90.0

    # Check solution
    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Total cost of solution is incorrect. Calculated: 47.77777777777778, actual: 90.0, diff: 42.22222222222222"
end


@testset "checkSolutionFeasibility test - activity not serviced" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
    solution.vehicleSchedules[1] = VehicleSchedule(solution.vehicleSchedules[1].vehicle,true)
    
    # Check solution
    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == false
    @test msg == "SOLUTION INFEASIBLE: Not all requests are serviced. Serviced: 0, not serviced: 3, nTaxi: 0, totalNTaxi: 0"
end

@testset "checkSolutionFeasibility test - activity already rejected" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Construct solution
    solution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
    solution.totalCost -= solution.vehicleSchedules[1].totalCost
    solution.totalRideTime -= solution.vehicleSchedules[1].totalTime
    solution.totalDistance -= solution.vehicleSchedules[1].totalDistance
    solution.totalIdleTime -= solution.vehicleSchedules[1].totalIdleTime
    solution.vehicleSchedules[1] = VehicleSchedule(solution.vehicleSchedules[1].vehicle,true)
    solution.totalCost += 3*scenario.taxiParameter

    # Check solution
    state = State(solution,Request(),3)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
end