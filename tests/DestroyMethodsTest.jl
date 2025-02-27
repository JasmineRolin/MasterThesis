using Test
using alns 
using domain 
using utils 
using offlinesolution


#==
 Test randomDestroy
==#
#@testset "randomDestroy test" begin 
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
    printSolution(solution,printRouteHorizontal)


    # Construct ALNS state
    currentState = ALNSState(solution,1,0)

    # Construct ALNS parameters
    parameters = ALNSParameters()

    # Destroy 
    randomDestroy!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    println(msg)
    printSolution(solution,printRouteHorizontal)

    randomDestroy!(scenario,currentState,parameters)
    solution.nTaxi += 1
    feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
    println(msg)
    printSolution(solution,printRouteHorizontal)
#end




