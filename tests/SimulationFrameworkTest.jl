using Test 
using Dates
using utils 
include("../simulation framework/SimulationFramework.jl")

using .SimulationFramework


#==
 Test InstanceReader 
==# 

#==
@testset "InstanceReader test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Small.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    solution = simulateScenario(scenario)
    println(solution)

    println("Simulation done")


end

@testset "Test InstanceReader on Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    solution = simulateScenario(scenario)

    println("Simulation done")


end
===#

requestFile = "tests/resources/Requests.csv"
vehiclesFile = "tests/resources/Vehicles.csv"
parametersFile = "tests/resources/Parameters.csv"
distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

solution = simulateScenario(scenario)

# Print routes
for schedule in solution.vehicleSchedules
    printRoute(schedule)
end

# Check routes
for schedule in solution.vehicleSchedules
    feasible, msg = checkRouteFeasibility(scenario,schedule)
    println(msg)
end