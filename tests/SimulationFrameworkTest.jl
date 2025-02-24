using Test 
using Dates
using utils 
using simulationframework


requestFile = "tests/resources/Requests.csv"
vehiclesFile = "tests/resources/Vehicles.csv"
parametersFile = "tests/resources/Parameters.csv"
distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

solution = simulateScenario(scenario)

# Check routes
for schedule in solution.vehicleSchedules
    feasible, msg = checkRouteFeasibility(scenario,schedule)
    println(msg)
end
