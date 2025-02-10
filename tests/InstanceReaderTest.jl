using Test 
using Dates
using utils 



#==
 Test InstanceReader 
==# 
@testset "InstanceReader test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile)

    x = 1

    # Check vehicles
    @test length(scenario.vehicles) == 4
    @test scenario.vehicles[1].depotId == scenario.vehicles[4].depotId

end

