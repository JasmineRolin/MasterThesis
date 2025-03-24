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


#==
@testset "routeFeasibility test - feasbile route" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    scenario.time[9,1] = 30
    scenario.time[11,4] = 22

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 405 - scenario.time[vehicle.depotId,4]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[1]
    request2 = scenario.requests[4]

    # Insert request 2 
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request2.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request2.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request2.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

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
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request2.pickUpActivity.id] + scenario.distance[request2.pickUpActivity.id,request2.dropOffActivity.id] + scenario.distance[request2.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)
   
    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
   @test feasible == true
   @test msg == ""

    # Case where waiting node is added before pickup 
    feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase1(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)])
    @test startOfServiceTimePickUp == 476 
    @test startOfServiceTimeDropOff == 480
    @test shiftAfterDropOff == 74 
    @test shiftBeforePickUp == 0
    @test shiftBetweenPickupAndDropOff == 0
    @test addWaitingActivity == true


    # Case where route needs to be shiftet forward 
    scenario.time[1,6] = 30
    feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase1(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)])
    @test startOfServiceTimePickUp == 460
    @test startOfServiceTimeDropOff == 492
    @test shiftAfterDropOff == 86
    @test shiftBeforePickUp == 8
    @test shiftBetweenPickupAndDropOff == 0
    @test addWaitingActivity == false

    # Case where route needs to be shiftet backwards 
    scenario.time[9,1] = 82
    scenario.time[1,6] = 2
    request1.dropOffActivity.timeWindow.startTime = 499
    request1.pickUpActivity.timeWindow.endTime = 500
    feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase1(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)])
    @test startOfServiceTimePickUp == 495
    @test startOfServiceTimeDropOff == 499
    @test shiftAfterDropOff == 93
    @test shiftBeforePickUp == -9
    @test shiftBetweenPickupAndDropOff == 0
    @test addWaitingActivity == false
end
==#


#==
@testset "Case5: routeFeasibility test - feasbile route" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    scenario.time[9,1] = 30
    scenario.time[11,4] = 22
    scenario.time[4,2] = 1
    scenario.time[7,9] = 1
    scenario.time[2,7] = 16

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 405 - scenario.time[vehicle.depotId,4]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[2]
    request2 = scenario.requests[4]

    # Insert request 2 
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request2.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request2.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request2.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

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
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request2.pickUpActivity.id] + scenario.distance[request2.pickUpActivity.id,request2.dropOffActivity.id] + scenario.distance[request2.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""

    printRouteHorizontal(vehicleSchedule)

    # Case where waiting node is added in between pick-up and drop-off 
    request1.requestType = PICKUP_REQUEST
    request1.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(386)
    request1.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    request1.maximumRideTime = findMaximumRideTime(request1.directDriveTime,200,1) 
    request1.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[2,7], request1.maximumRideTime)

    feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase5(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)],2,scenario.requests)
    @test startOfServiceTimePickUp == 409
    @test startOfServiceTimeDropOff == 427
    @test shiftAfterDropOff == 10
    @test shiftBeforePickUp == 1
    @test shiftBetweenPickupAndDropOff == 0
    @test addWaitingActivity == false


end

==#

@testset "Case6: routeFeasibility test - feasbile route" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    scenario.time[9,1] = 30
    scenario.time[11,4] = 22
    scenario.time[4,2] = 1
    scenario.time[7,9] = 1
    scenario.time[2,7] = 16

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 405 - scenario.time[vehicle.depotId,4]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[2]
    request2 = scenario.requests[4]

    # Insert request 2 
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request2.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request2.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request2.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

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
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request2.pickUpActivity.id] + scenario.distance[request2.pickUpActivity.id,request2.dropOffActivity.id] + scenario.distance[request2.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""

    printRouteHorizontal(vehicleSchedule)

    # Case where waiting node is added in between pick-up and drop-off 
    request1.requestType = PICKUP_REQUEST
    request1.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(386)
    request1.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    request1.maximumRideTime = findMaximumRideTime(request1.directDriveTime,200,1) 
    request1.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[2,7], request1.maximumRideTime)

    feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity = determineServiceTimesAndShiftsCase6(scenario.time,scenario.serviceTimes,request1,vehicleSchedule.route[1:(end-1)],2,scenario.requests)
    @test startOfServiceTimePickUp == 409
    @test startOfServiceTimeDropOff == 427
    @test shiftAfterDropOff == 10
    @test shiftBeforePickUp == 1
    @test shiftBetweenPickupAndDropOff == 0
    @test addWaitingActivity == false


end