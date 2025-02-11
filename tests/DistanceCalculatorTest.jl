using Test 
using Dates
using utils 

#==
Test minutesSinceMidnight 
==#
@testset "getDistanceAndTimeMatrix test" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile)


    # Retrieve distance and time matrix 
    distanceMatrix, timeMatrix = getDistanceAndTimeMatrix(scenario)

    @test int(distanceMatrix[2,1]/1000) == 5.9

end
