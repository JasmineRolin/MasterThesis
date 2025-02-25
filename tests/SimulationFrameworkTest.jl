using Test 
using Dates
using utils 
using simulationframework


requestFile = "tests/resources/RequestsToTestSimulation.csv"
vehiclesFile = "tests/resources/Vehicles.csv"
parametersFile = "tests/resources/Parameters.csv"
distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

# Read instance 
scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

solution = simulateScenario(scenario)
solution.nTaxi += length(scenario.onlineRequests) # Remove when online request are implemented

checkSolutionFeasibility(scenario,solution)
