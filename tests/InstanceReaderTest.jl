using Test 
using Dates
using utils 



# #==
#  Test InstanceReader 
# ==# 


# @testset "InstanceReader test" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Check vehicles
#     @test length(scenario.vehicles) == 4
#     @test scenario.vehicles[1].depotId == scenario.vehicles[4].depotId

#     # Check requests 
#     @test length(scenario.requests) == 5

#     # Direct drive time 
#     @test scenario.requests[1].directDriveTime == 2
#     @test scenario.requests[2].directDriveTime == 9
#     @test scenario.requests[3].directDriveTime == 8
#     @test scenario.requests[4].directDriveTime == 13
#     @test scenario.requests[5].directDriveTime == 13

#     # Maximum drive time 
#     @test scenario.requests[1].maximumRideTime == 20
#     @test scenario.requests[2].maximumRideTime == 27
#     @test scenario.requests[3].maximumRideTime == 24
#     @test scenario.requests[4].maximumRideTime == 39
#     @test scenario.requests[5].maximumRideTime == 39

#     # Time windows 
#     requestTime1 = 495 
#     @test scenario.requests[1].pickUpActivity.timeWindow.startTime == requestTime1 - 15 - 20
#     @test scenario.requests[1].pickUpActivity.timeWindow.endTime == requestTime1 + 5 - 2 
#     @test scenario.requests[1].dropOffActivity.timeWindow.startTime == requestTime1 - 15
#     @test scenario.requests[1].dropOffActivity.timeWindow.endTime == requestTime1 + 5

#     requestTime2 = 870 
#     @test scenario.requests[2].pickUpActivity.timeWindow.startTime == requestTime2 - 5
#     @test scenario.requests[2].pickUpActivity.timeWindow.endTime == requestTime2 + 15 
#     @test scenario.requests[2].dropOffActivity.timeWindow.startTime == requestTime2 - 5 + 9 
#     @test scenario.requests[2].dropOffActivity.timeWindow.endTime == requestTime2 + 15 + 27
    
#     requestTime3 = 530
#     @test scenario.requests[3].pickUpActivity.timeWindow.startTime == requestTime3 - 15 - 24
#     @test scenario.requests[3].pickUpActivity.timeWindow.endTime == requestTime3 + 5 - 8 
#     @test scenario.requests[3].dropOffActivity.timeWindow.startTime == requestTime3 - 15
#     @test scenario.requests[3].dropOffActivity.timeWindow.endTime == requestTime3 + 5

#     requestTime4 = 425
#     @test scenario.requests[4].pickUpActivity.timeWindow.startTime == requestTime4 - 15 - 39 
#     @test scenario.requests[4].pickUpActivity.timeWindow.endTime == requestTime4 + 5 - 13
#     @test scenario.requests[4].dropOffActivity.timeWindow.startTime == requestTime4 - 15
#     @test scenario.requests[4].dropOffActivity.timeWindow.endTime == requestTime4 + 5

#     requestTime5 = 990 
#     @test scenario.requests[5].pickUpActivity.timeWindow.startTime == requestTime5 - 5
#     @test scenario.requests[5].pickUpActivity.timeWindow.endTime == requestTime5 + 15 
#     @test scenario.requests[5].dropOffActivity.timeWindow.startTime == requestTime5 - 5 + 13
#     @test scenario.requests[5].dropOffActivity.timeWindow.endTime == requestTime5 + 15 + 39

#     # Check online and offline requests
#     for (i,request) in enumerate(scenario.requests)
#         if request.callTime == 0
#             @test request in scenario.offlineRequests
#         else
#             @test request in scenario.onlineRequests
#         end
#     end


# end



# @testset "Test InstanceReader on Konsentra" begin 
#     requestFile = "Data/Konsentra/TransformedData_Data.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "Data/Matrices/distanceMatrix_Konsentra.txt"
#     timeMatrixFile = "Data/Matrices/timeMatrix_Konsentra.txt"
#     scenarioName = "Konsentra_Data"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     @test length(scenario.requests) == 28 

# end


using Plots
# Create gant chart of vehicles and requests
function createGantChartOfRequestsAndVehicles(vehicles, requests, requestBank,titleString)
    p = plot(size=(1600,900))
    yPositions = []
    yLabels = []
    yPos = 1
    
    for (idx,vehicle) in enumerate(vehicles)
        # Vehicle availability window
        tw = vehicle.availableTimeWindow

        if idx == 1
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=5, label="Vehicle TW", color=:blue)
        else
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=5,label="", color=:blue)
        end

        # Plot vertical dashed lines for start and end of time window
        vline!([tw.startTime], linestyle=:dash, color=:grey, linewidth=2, label="")
        vline!([tw.endTime], linestyle=:dash, color=:grey, linewidth=2, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(vehicle.id)")
        yPos += 1
    end
    
    legendServiced = false 
    legendUnserviced = false
    for (idx,request) in enumerate(requests)
        pickupTW = request.pickUpActivity.timeWindow
        dropoffTW = request.dropOffActivity.timeWindow
        
        # Determine color based on whether request is serviced
        unServiced = request.id in requestBank
        colorPickup = unServiced ? :yellow : :green
        colorDropoff = unServiced ? :orange : :purple

        # Plot pickup and dropoff window as a bar
        if unServiced && !legendUnserviced
            legendUnserviced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="Unserviced Pickup TW", color=colorPickup)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5, label="Unserviced Dropoff TW", color=colorDropoff)
        elseif !unServiced && !legendServiced
            legendServiced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="Serviced Pickup TW", color=colorPickup)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5, label="Serviced Dropoff TW", color=colorDropoff)
        else
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="", color=colorPickup)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5,label="", color=colorDropoff)
        end 

      
        
        push!(yPositions, yPos)
        push!(yLabels, "Request $(request.id)")
        yPos += 1
    end
    
    plot!(p, yticks=(yPositions, yLabels))
    xlabel!("Time (Minutes after Midnight)")
    title!(titleString)

    return p
end


n = 500
for i in 1:10
    requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
    vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
    scenarioName = string("Konsentra_Data_",n,"_",i)
    
    
    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    
    display(createGantChartOfRequestsAndVehicles(scenario.vehicles, scenario.requests, [],scenarioName))
    
    
end

