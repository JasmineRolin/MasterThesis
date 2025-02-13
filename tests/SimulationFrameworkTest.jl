using Test 
using Dates
using utils 
include("../simulation framework/SimulationFramework.jl")

using .SimulationFramework

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
    @test scenario.requests[1].pickUpActivity.timeWindow.startTime == requestTime1 - 15 - 30 
    @test scenario.requests[1].pickUpActivity.timeWindow.endTime == requestTime1 + 5 - 10 
    @test scenario.requests[1].dropOffActivity.timeWindow.startTime == requestTime1 - 15
    @test scenario.requests[1].dropOffActivity.timeWindow.endTime == requestTime1 + 5

    requestTime2 = 870 
    @test scenario.requests[2].pickUpActivity.timeWindow.startTime == requestTime2 - 5
    @test scenario.requests[2].pickUpActivity.timeWindow.endTime == requestTime2 + 15 
    @test scenario.requests[2].dropOffActivity.timeWindow.startTime == requestTime2 - 5 + 50 
    @test scenario.requests[2].dropOffActivity.timeWindow.endTime == requestTime2 + 15 + 100
    
    requestTime3 = 530
    @test scenario.requests[3].pickUpActivity.timeWindow.startTime == requestTime3 - 15 - 100
    @test scenario.requests[3].pickUpActivity.timeWindow.endTime == requestTime3 + 5 - 50 
    @test scenario.requests[3].dropOffActivity.timeWindow.startTime == requestTime3 - 15
    @test scenario.requests[3].dropOffActivity.timeWindow.endTime == requestTime3 + 5

    requestTime4 = 425
    @test scenario.requests[4].pickUpActivity.timeWindow.startTime == requestTime4 - 15 - 140 
    @test scenario.requests[4].pickUpActivity.timeWindow.endTime == requestTime4 + 5 - 70 
    @test scenario.requests[4].dropOffActivity.timeWindow.startTime == requestTime4 - 15
    @test scenario.requests[4].dropOffActivity.timeWindow.endTime == requestTime4 + 5

    requestTime5 = 990 
    @test scenario.requests[5].pickUpActivity.timeWindow.startTime == requestTime5 - 5
    @test scenario.requests[5].pickUpActivity.timeWindow.endTime == requestTime5 + 15 
    @test scenario.requests[5].dropOffActivity.timeWindow.startTime == requestTime5 - 5 + 70
    @test scenario.requests[5].dropOffActivity.timeWindow.endTime == requestTime5 + 15 + 140

    # Check online and offline requests
    for (i,request) in enumerate(scenario.requests)
        if request.callTime == 0
            @test request in scenario.offlineRequests
        else
            @test request in scenario.onlineRequests
        end
    end

    simulateScenario(scenario)


end

@testset "Test InstanceReader on Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile)

    simulateScenario(scenario)


    @test length(scenario.requests) == 28 

end
