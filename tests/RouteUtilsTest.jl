using Test 
using utils 
using domain 

# #==
# #  Test printVehicleSchedule
# ==#
# @testset "printVehicleSchedule test" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

#     # Insert request
#     insertRequest!(scenario.requests[1],vehicleSchedule,1,1,scenario)

#     printRoute(vehicleSchedule)

# end 



# #==
#  Test routeFeasibility
# ==#
# @testset "routeFeasibility test - feasbile route" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     # Update start depot 
#     startTime = 415
#     vehicleSchedule.route[1].startOfServiceTime = startTime
#     vehicleSchedule.route[1].endOfServiceTime = startTime


#     # Insert request
#     request = scenario.requests[1]
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff = 16 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,pickUpActivity)
#     insert!(vehicleSchedule.route,3,dropOffActivity)

#     # Insert waiting nodes
#     route = vehicleSchedule.route
#     startOfServiceWaiting = route[3].endOfServiceTime 
#     endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,4,waitingActivity)

#     startOfServiceWaiting = route[2].endOfServiceTime 
#     endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,3,waitingActivity)

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     vehicleSchedule.numberOfWalking = [0,1,1,0,0,0]
#     vehicleSchedule.totalIdleTime = 862.0
   
#     # Check route feasibility
#     feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
#     @test feasible == true
#     @test msg == ""

# end


# @testset "routeFeasibility test - infeasible active time window" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     startTime = 415
#     vehicleSchedule.route[1].startOfServiceTime = 0
#     vehicleSchedule.route[1].endOfServiceTime = 0

#     request = scenario.requests[1]
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff = 16 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,pickUpActivity)
#     insert!(vehicleSchedule.route,3,dropOffActivity)

#     # Insert waiting nodes
#     route = vehicleSchedule.route
#     startOfServiceWaiting = route[3].endOfServiceTime 
#     endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,4,waitingActivity)
    
#     startOfServiceWaiting = route[2].endOfServiceTime 
#     endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,3,waitingActivity)

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp )/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     vehicleSchedule.numberOfWalking = [0,1,1,0,0,0]
   
#     feasible, msg = checkRouteFeasibility(scenario, vehicleSchedule)
#     @test feasible == false
#     @test msg == "ROUTE INFEASIBLE: Active time window of vehicle 1 is incorrect"
# end


# @testset "routeFeasibility test - infeasible dropoff time" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     # Update start depot 
#     startTime = 415
#     vehicleSchedule.route[1].startOfServiceTime = startTime
#     vehicleSchedule.route[1].endOfServiceTime = startTime
    
#     # Insert request
#     request = scenario.requests[1]
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff =  endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,pickUpActivity)
#     insert!(vehicleSchedule.route,3,dropOffActivity)

#     # Insert waiting nodes
#     route = vehicleSchedule.route
#     startOfServiceWaiting = route[3].endOfServiceTime 
#     endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,4,waitingActivity)

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    
#     # Check route feasibility
#     feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
#     @test feasible == false
#     @test msg == "ROUTE INFEASIBLE: Time window not respected for activity 6 on vehicle 1, Start/End of Service: (467, 469), Time Window: (480, 500)"
   

# end

# @testset "routeFeasibility test - dropoff before pickup" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     # Update start depot 
#     startTime = 415
#     vehicleSchedule.route[1].startOfServiceTime = startTime
#     vehicleSchedule.route[1].endOfServiceTime = startTime
    
#     # Insert request
#     request = scenario.requests[1]
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff =  endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,dropOffActivity)
#     insert!(vehicleSchedule.route,3,pickUpActivity)
    

#     # Update end depot 
#     vehicleSchedule.route[4].startOfServiceTime = endOfServiceTimeDropOff + scenario.time[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.route[4].endOfServiceTime = endOfServiceTimeDropOff + scenario.time[request.dropOffActivity.id,vehicle.depotId]

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.activeTimeWindow.endTime = dropOffActivity.endOfServiceTime + scenario.time[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 0.0
#     vehicleSchedule.numberOfWalking = [0,0,1,0]
    
#     # Check route feasibility
#     feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
#     @test feasible == false
#     @test msg == "ROUTE INFEASIBLE: Drop-off 6 before pick-up, vehicle: 1"
   

# end


# @testset "routeFeasibility test - maximum ride time exceeded" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     # Update start depot 
#     startTime = 415
#     vehicleSchedule.route[1].startOfServiceTime = startTime
#     vehicleSchedule.route[1].endOfServiceTime = startTime
    
#     # Insert request
#     request = scenario.requests[1]
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff =  25 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,pickUpActivity)
#     insert!(vehicleSchedule.route,3,dropOffActivity)
    

#     # Insert waiting nodes
#     route = vehicleSchedule.route
#     startOfServiceWaiting = route[3].endOfServiceTime 
#     endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,4,waitingActivity)

#     startOfServiceWaiting = route[2].endOfServiceTime 
#     endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,3,waitingActivity)

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
#     vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    
#     # Check route feasibility
#     feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
#     @test feasible == false
#     @test msg == "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off 6 on vehicle 1"
   

# end



# @testset "determineServiceTimesAndShiftsCase1" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
#     scenario.time[9,1] = 30
#     scenario.time[11,4] = 22

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     # Update start depot 
#     startTime = 405 - scenario.time[vehicle.depotId,4]
#     vehicleSchedule.route[1].startOfServiceTime = startTime
#     vehicleSchedule.route[1].endOfServiceTime = startTime

#     # Requests  
#     request1 = scenario.requests[1]
#     request1.maximumRideTime = 40
#     request2 = scenario.requests[4]

#     # Insert request 2 
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request2.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request2.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request2.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,pickUpActivity)
#     insert!(vehicleSchedule.route,3,dropOffActivity)

#     # Insert waiting nodes
#     route = vehicleSchedule.route
#     startOfServiceWaiting = route[3].endOfServiceTime 
#     endOfServiceWaiting = route[end].startOfServiceTime - scenario.time[route[3].activity.id,route[end].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,4,waitingActivity)

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request2.pickUpActivity.id] + scenario.distance[request2.pickUpActivity.id,request2.dropOffActivity.id] + scenario.distance[request2.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
#     vehicleSchedule.numberOfWalking = [0,1,0,0,0]
#     vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)
   
#     # Check route feasibility
#     feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
#     @test feasible == true
#     @test msg == ""

#     # Case where waiting node is added before pickup 
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase1(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 476 
#     @test startOfServiceTimeDropOff == 480
#     @test shiftAfterDropOff == 74 
#     @test shiftBeforePickUp == 0
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == true


#     # Case where route needs to be shiftet forward 
#     scenario.time[1,6] = 30
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase1(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 460
#     @test startOfServiceTimeDropOff == 492
#     @test shiftAfterDropOff == 86
#     @test shiftBeforePickUp == 8
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == false

#     # Case where route needs to be shiftet backwards 
#     scenario.time[9,1] = 82
#     scenario.time[1,6] = 2
#     request1.dropOffActivity.timeWindow.startTime = 499
#     request1.pickUpActivity.timeWindow.endTime = 500
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase1(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 495
#     @test startOfServiceTimeDropOff == 499
#     @test shiftAfterDropOff == 93
#     @test shiftBeforePickUp == -9
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == false
# end



# @testset "determineServiceTimesAndShiftsCase2" begin 
#     requestFile = "tests/resources/Requests.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
#     scenarioName = "Small"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
#     scenario.time[1,6] = 15
#     scenario.time[11,4] = 40
#     scenario.time[9,1] = 31

#     # Create VehicleSchedule
#     vehicle = scenario.vehicles[1]
#     vehicleSchedule = VehicleSchedule(vehicle)

#     #== Check feasible route ==#
#     # Update start depot 
#     startTime = 466 - scenario.time[vehicle.depotId,1]
#     vehicleSchedule.route[1].startOfServiceTime = startTime
#     vehicleSchedule.route[1].endOfServiceTime = startTime

#     # Requests  
#     request1 = scenario.requests[1]
#     request2 = scenario.requests[4]

#     # Insert request 2 
#     startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request1.pickUpActivity.id] 
#     endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

#     startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
#     endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

#     pickUpActivity = ActivityAssignment(request1.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
#     dropOffActivity = ActivityAssignment(request1.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

#     insert!(vehicleSchedule.route,2,pickUpActivity)
#     insert!(vehicleSchedule.route,3,dropOffActivity)

#     # Insert waiting nodes
#     route = vehicleSchedule.route
#     startOfServiceWaiting = route[3].endOfServiceTime 
#     endOfServiceWaiting = route[end].startOfServiceTime - scenario.time[route[3].activity.id,route[end].activity.id]
#     waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
#     insert!(vehicleSchedule.route,4,waitingActivity)

#     # Update vehicle schedule
#     vehicleSchedule.activeTimeWindow.startTime = startTime
#     vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request1.pickUpActivity.id] + scenario.distance[request1.pickUpActivity.id,request1.dropOffActivity.id] + scenario.distance[request1.dropOffActivity.id,vehicle.depotId]
#     vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
#     vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
#     vehicleSchedule.numberOfWalking = [0,1,0,0,0]
#     vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)
   
#     # Check route feasibility
#     feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
#     @test feasible == true
#     @test msg == ""

#     # Case where pick up and drop off can be inserted directly 
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase2(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 415
#     @test startOfServiceTimeDropOff == 430
#     @test shiftAfterDropOff == -3 
#     @test shiftBeforePickUp == -43
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == false

#     # Shift back wards when inserting drop off and pick up 
#     scenario.time[4,9] = 10
#     request1.dropOffActivity.timeWindow.startTime = 475
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase2(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 417
#     @test startOfServiceTimeDropOff == 429
#     @test shiftAfterDropOff == -4
#     @test shiftBeforePickUp == -41
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == false

#     # Shift forwards when inserting drop off 
#     scenario.time[4,9] = 10
#     scenario.time[9,1] = 60
#     request1.dropOffActivity.timeWindow.startTime = 475
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase2(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 409
#     @test startOfServiceTimeDropOff == 421
#     @test shiftAfterDropOff == 17
#     @test shiftBeforePickUp == -49
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == false

#     # Insert waiting after drop off 
#     scenario.time[4,9] = 10
#     scenario.time[9,1] = 20
#     request1.dropOffActivity.timeWindow.startTime = 480
#     feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase2(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)])
#     @test feasible == true 
#     @test startOfServiceTimePickUp == 417
#     @test startOfServiceTimeDropOff == 429
#     @test shiftAfterDropOff == 0
#     @test shiftBeforePickUp == -41
#     @test shiftBetweenPickupAndDropOff == 0
#     @test addWaitingActivity == true
# end



#@testset "determineServiceTimesAndShiftsCase3" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    scenario.time[1,6] = 15
    scenario.time[11,4] = 30
    scenario.time[9,1] = 31
    scenario.time[4,1] = 35

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 466 - scenario.time[vehicle.depotId,1]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[1]
    request1.pickUpActivity.timeWindow.startTime = 450
    request1.dropOffActivity.timeWindow.startTime = 460
    request2 = scenario.requests[4]
    request2.dropOffActivity.timeWindow.startTime = 480 
    request2.dropOffActivity.timeWindow.endTime = 600
    request2.maximumRideTime = 80

    # Insert request 1
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request1.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request1.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request1.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[end].startOfServiceTime - scenario.time[route[3].activity.id,route[end].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,4,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request1.pickUpActivity.id] + scenario.distance[request1.pickUpActivity.id,request1.dropOffActivity.id] + scenario.distance[request1.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)
   
    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    # @test feasible == true
    # @test msg == ""

    # Case where pick up can be inserted by shifting route backwards and drop off can be inserted directly 
    # feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase3(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)],1,3)
    # @test feasible == true 
    # @test startOfServiceTimePickUp == 417
    # @test startOfServiceTimeDropOff == 487
    # @test shiftAfterDropOff == 18 
    # @test shiftBeforePickUp == -31
    # @test shiftBetweenPickupAndDropOff == -12
    # @test addWaitingActivity == false

    # Shift back wards when inserting pick up and drop off  
    # request2.dropOffActivity.timeWindow.startTime = 455 
    # request2.dropOffActivity.timeWindow.endTime = 465
    # request1.dropOffActivity.timeWindow.startTime = 467
    # scenario.time[9,6] = 8
    # feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase3(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)],1,2)
    # @test feasible == true 
    # @test startOfServiceTimePickUp == 405
    # @test startOfServiceTimeDropOff == 457
    # @test shiftAfterDropOff == -16
    # @test shiftBeforePickUp == -43
    # @test shiftBetweenPickupAndDropOff == -24
    # @test addWaitingActivity == false

    # Shift forwards when inserting pick up and drop off  
    # request2.dropOffActivity.timeWindow.startTime = 460
    # request2.dropOffActivity.timeWindow.endTime = 465
    # request1.dropOffActivity.timeWindow.startTime = 467
    # scenario.time[9,6] = 8
    # scenario.time[1,9] = 2
    # feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase3(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)],1,2)
    # @test feasible == false 
    # @test startOfServiceTimePickUp == 0
    # @test startOfServiceTimeDropOff == 0
    # @test shiftAfterDropOff == 0
    # @test shiftBeforePickUp == 0
    # @test shiftBetweenPickupAndDropOff == 0
    # @test addWaitingActivity == false

    # Shift R2 backwards and R1 forwards
    request2.dropOffActivity.timeWindow.startTime = 455
    request2.dropOffActivity.timeWindow.endTime = 465
    request1.dropOffActivity.timeWindow.startTime = 467
    request1.dropOffActivity.timeWindow.endTime = 485
    scenario.time[9,6] = 35
    vehicleSchedule.route[1].activity.timeWindow.startTime = 250
    feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase3(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)],1,2)
    @test feasible == false 
    @test startOfServiceTimePickUp == 0
    @test startOfServiceTimeDropOff == 0
    @test shiftAfterDropOff == 0
    @test shiftBeforePickUp == 0
    @test shiftBetweenPickupAndDropOff == 0
    @test addWaitingActivity == false

    # # Insert waiting after drop off 
    # scenario.time[4,9] = 10
    # scenario.time[9,1] = 20
    # request1.dropOffActivity.timeWindow.startTime = 480
    # feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase2(scenario.time,scenario.serviceTimes,request2,vehicleSchedule.route[1:(end-1)])
    # # @test feasible == true 
    # # @test startOfServiceTimePickUp == 417
    # # @test startOfServiceTimeDropOff == 429
    # # @test shiftAfterDropOff == 0
    # # @test shiftBeforePickUp == -41
    # # @test shiftBetweenPickupAndDropOff == 0
    # # @test addWaitingActivity == true
#end