using Test 
using Dates

include("../offlinesolution/src/ConstructionHeuristic.jl")

using utils
using domain
using .ConstructionHeuristic



#==
 Test InstanceReader 
==# 


@testset "InstanceReader test" begin 
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
        println(msg)
    end

    @test solution.nTaxi == 0
    

end

