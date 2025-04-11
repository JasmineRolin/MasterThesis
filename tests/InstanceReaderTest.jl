using Test 
using Dates
using utils, domain


#==
 Allowed delay/early arrival
==#
global MAX_DELAY = 15
global MAX_EARLY_ARRIVAL = 5


#==
 Test InstanceReader 
==# 


@testset "InstanceReader test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Check vehicles
    @test length(scenario.vehicles) == 4
    @test scenario.vehicles[1].depotId == scenario.vehicles[4].depotId

    # Check requests 
    @test length(scenario.requests) == 5

    # Direct drive time 
    @test scenario.requests[1].directDriveTime == 2
    @test scenario.requests[2].directDriveTime == 9
    @test scenario.requests[3].directDriveTime == 8
    @test scenario.requests[4].directDriveTime == 13
    @test scenario.requests[5].directDriveTime == 13

    # Maximum drive time 
    @test scenario.requests[1].maximumRideTime == 20
    @test scenario.requests[2].maximumRideTime == 27
    @test scenario.requests[3].maximumRideTime == 24
    @test scenario.requests[4].maximumRideTime == 39
    @test scenario.requests[5].maximumRideTime == 39

    # Time windows 
    requestTime1 = 495 
    @test scenario.requests[1].pickUpActivity.timeWindow.startTime == requestTime1 - MAX_EARLY_ARRIVAL
    @test scenario.requests[1].pickUpActivity.timeWindow.endTime == requestTime1 + MAX_DELAY
    @test scenario.requests[1].dropOffActivity.timeWindow.startTime == requestTime1 - MAX_EARLY_ARRIVAL + 2
    @test scenario.requests[1].dropOffActivity.timeWindow.endTime == requestTime1 + MAX_DELAY + 20

    requestTime2 = 870 
    @test scenario.requests[2].pickUpActivity.timeWindow.startTime == requestTime2 - MAX_DELAY - 27
    @test scenario.requests[2].pickUpActivity.timeWindow.endTime == requestTime2 + MAX_EARLY_ARRIVAL - 9 
    @test scenario.requests[2].dropOffActivity.timeWindow.startTime == requestTime2 - MAX_DELAY 
    @test scenario.requests[2].dropOffActivity.timeWindow.endTime == requestTime2 + MAX_EARLY_ARRIVAL
    
    requestTime3 = 530
    @test scenario.requests[3].pickUpActivity.timeWindow.startTime == requestTime3 - MAX_EARLY_ARRIVAL
    @test scenario.requests[3].pickUpActivity.timeWindow.endTime == requestTime3 + MAX_DELAY 
    @test scenario.requests[3].dropOffActivity.timeWindow.startTime == requestTime3 - MAX_EARLY_ARRIVAL + 8
    @test scenario.requests[3].dropOffActivity.timeWindow.endTime == requestTime3 + MAX_DELAY + 24

    requestTime4 = 425
    @test scenario.requests[4].pickUpActivity.timeWindow.startTime == requestTime4 - MAX_EARLY_ARRIVAL
    @test scenario.requests[4].pickUpActivity.timeWindow.endTime == requestTime4 + MAX_DELAY 
    @test scenario.requests[4].dropOffActivity.timeWindow.startTime == requestTime4 - MAX_EARLY_ARRIVAL + 13
    @test scenario.requests[4].dropOffActivity.timeWindow.endTime == requestTime4 + MAX_DELAY + 39

    requestTime5 = 990 
    @test scenario.requests[5].pickUpActivity.timeWindow.startTime == requestTime5 - MAX_DELAY - 39
    @test scenario.requests[5].pickUpActivity.timeWindow.endTime == requestTime5 + MAX_EARLY_ARRIVAL - 13 
    @test scenario.requests[5].dropOffActivity.timeWindow.startTime == requestTime5 - MAX_DELAY
    @test scenario.requests[5].dropOffActivity.timeWindow.endTime == requestTime5 + MAX_EARLY_ARRIVAL 

    # Check online and offline requests
    for (i,request) in enumerate(scenario.requests)
        if request.callTime == 0
            @test request in scenario.offlineRequests
        else
            @test request in scenario.onlineRequests
        end
    end


end



@testset "Test InstanceReader on Konsentra" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
    timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
    scenarioName = "Konsentra_Data"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    @test length(scenario.requests) == 28 

end

