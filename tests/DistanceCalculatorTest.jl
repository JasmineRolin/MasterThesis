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

    @test round(distanceMatrix[2,1]/1000.0,digits=1) == 6.0

end
