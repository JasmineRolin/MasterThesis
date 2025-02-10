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

    # Check vehicles
    @test length(scenario.vehicles) == 4
    @test scenario.vehicles[1].depotId == scenario.vehicles[4].depotId

    # Check requests 
    @test length(scenario.requests) == 5

    # Direct drive time 
    @test scenario.requests[1].directDriveTime == 10
    @test scenario.requests[2].directDriveTime == 50
    @test scenario.requests[3].directDriveTime == 50
    @test scenario.requests[4].directDriveTime == 70
    @test scenario.requests[5].directDriveTime == 70

    # Maximum drive time 
    @test scenario.requests[1].maximumRideTime == 30
    @test scenario.requests[2].maximumRideTime == 100
    @test scenario.requests[3].maximumRideTime == 100
    @test scenario.requests[4].maximumRideTime == 140
    @test scenario.requests[5].maximumRideTime == 140

    # Time windows 
    requestTime1 = 495 
    @test scenario.requests[1].pickUpTimeWindow.startTime == requestTime1 - 15 - 30 
    @test scenario.requests[1].pickUpTimeWindow.endTime == requestTime1 + 5 - 10 
    @test scenario.requests[1].dropOffTimeWindow.startTime == requestTime1 - 15
    @test scenario.requests[1].dropOffTimeWindow.endTime == requestTime1 + 5

    requestTime2 = 870 
    @test scenario.requests[2].pickUpTimeWindow.startTime == requestTime2 - 5
    @test scenario.requests[2].pickUpTimeWindow.endTime == requestTime2 + 15 
    @test scenario.requests[2].dropOffTimeWindow.startTime == requestTime2 - 5 + 50 
    @test scenario.requests[2].dropOffTimeWindow.endTime == requestTime2 + 15 + 100
    
    requestTime3 = 530
    @test scenario.requests[3].pickUpTimeWindow.startTime == requestTime3 - 15 - 100
    @test scenario.requests[3].pickUpTimeWindow.endTime == requestTime3 + 5 - 50 
    @test scenario.requests[3].dropOffTimeWindow.startTime == requestTime3 - 15
    @test scenario.requests[3].dropOffTimeWindow.endTime == requestTime3 + 5

    requestTime4 = 425
    @test scenario.requests[4].pickUpTimeWindow.startTime == requestTime4 - 15 - 140 
    @test scenario.requests[4].pickUpTimeWindow.endTime == requestTime4 + 5 - 70 
    @test scenario.requests[4].dropOffTimeWindow.startTime == requestTime4 - 15
    @test scenario.requests[4].dropOffTimeWindow.endTime == requestTime4 + 5

    requestTime5 = 990 
    @test scenario.requests[5].pickUpTimeWindow.startTime == requestTime5 - 5
    @test scenario.requests[5].pickUpTimeWindow.endTime == requestTime5 + 15 
    @test scenario.requests[5].dropOffTimeWindow.startTime == requestTime5 - 5 + 70
    @test scenario.requests[5].dropOffTimeWindow.endTime == requestTime5 + 15 + 140


end

@testset "Test InstanceReader on Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile)

    @test length(scenario.requests) == 28 

end
