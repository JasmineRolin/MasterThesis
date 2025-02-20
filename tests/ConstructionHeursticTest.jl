using Test 

using utils, domain, offlinesolution


#==
 Test ConstructionHeuristicTest 
==# 
@testset "ConstructionHeuristicTest test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    solution = Solution(scenario)
    solution = simpleConstruction(scenario)

    # Print routes
    for schedule in solution.vehicleSchedules
        printRoute(schedule)
    end

    # Check routes
    for schedule in solution.vehicleSchedules
        feasible, msg = checkRouteFeasibility(scenario,schedule)
        @test feasible == true
    end

    @test solution.nTaxi == 0
end

