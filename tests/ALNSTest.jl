using Test 
using alns, domain, utils, offlinesolution


#@testset "ALNS test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
    timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
    alnsParametersFile = "tests/resources/ALNSParameters.json"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    # Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    # Run ALNS 
    solution = runALNS(scenario,scenario.offlineRequests,destroyMethods,repairMethods,simpleConstruction,alnsParametersFile)

#end