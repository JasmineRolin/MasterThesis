using Test 
using utils 
using domain 

#==
#  Test printVehicleSchedule
==#
@testset "printVehicleSchedule test" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

    # Insert request
    insertRequest!(scenario.requests[1],vehicleSchedule,1,1,scenario,[10,10,10,10],[12,12,12,12],Vector{Int}())

    printRoute(vehicleSchedule)

end 



#==
 Test routeFeasibility
==#
@testset "routeFeasibility test - feasbile route" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 445
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime


    # Insert request
    request = scenario.requests[1]
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff = 16 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,4,waitingActivity)

    startOfServiceWaiting = route[2].endOfServiceTime 
    endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,3,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,1,0,0,0]
    vehicleSchedule.totalIdleTime = 832
   
    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""

end


@testset "routeFeasibility test - infeasible active time window" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    startTime = 415
    vehicleSchedule.route[1].startOfServiceTime = 0
    vehicleSchedule.route[1].endOfServiceTime = 0

    request = scenario.requests[1]
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff = 16 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,4,waitingActivity)
    
    startOfServiceWaiting = route[2].endOfServiceTime 
    endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,3,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp )/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,1,0,0,0]
   
    feasible, msg = checkRouteFeasibility(scenario, vehicleSchedule)
    @test feasible == false
    @test msg == "ROUTE INFEASIBLE: Active time window of vehicle 1 is incorrect"
end


@testset "routeFeasibility test - infeasible dropoff time" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 435
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime
    
    # Insert request
    request = scenario.requests[1]
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff =  endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,4,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    
    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == false
    @test msg == "ROUTE INFEASIBLE: Time window not respected for activity 1 on vehicle 1, Start/End of Service: (483, 485), Time Window: (490, 510)"
   

end

@testset "routeFeasibility test - dropoff before pickup" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 415
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime
    
    # Insert request
    request = scenario.requests[1]
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff =  endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,dropOffActivity)
    insert!(vehicleSchedule.route,3,pickUpActivity)
    

    # Update end depot 
    vehicleSchedule.route[4].startOfServiceTime = endOfServiceTimeDropOff + scenario.time[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.route[4].endOfServiceTime = endOfServiceTimeDropOff + scenario.time[request.dropOffActivity.id,vehicle.depotId]

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = dropOffActivity.endOfServiceTime + scenario.time[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 0.0
    vehicleSchedule.numberOfWalking = [0,0,1,0]
    
    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == false
    @test msg == "ROUTE INFEASIBLE: Drop-off 6 before pick-up, vehicle: 1"
   

end


@testset "routeFeasibility test - maximum ride time exceeded" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 445
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime
    
    # Insert request
    request = scenario.requests[1]
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes

    startOfServiceDropOff =  25 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)
    

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,4,waitingActivity)

    startOfServiceWaiting = route[2].endOfServiceTime 
    endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
    insert!(vehicleSchedule.route,3,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    
    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == false
    @test msg == "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off 6 on vehicle 1, END PU/START DO: (495, 522), Ride time: 27, Maximum ride time: 20, direct drive time: 2"
   

end



@testset "Check feasibility of insertion: W - ROUTE - P - D - W" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    scenario.time[9,1] = 50
    scenario.time[11,4] = 22
    scenario.time[1,6] = 20

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 420 - scenario.time[vehicle.depotId,4]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[1]
    request1.maximumRideTime = 40
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

    # Insert pick up and drop off at end of schedule block 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete= checkFeasibilityOfInsertionAtPosition(request1,vehicleSchedule,4,4,scenario)
    @test feasible == true
    @test newStartOfServiceTimes[1] == 401
    @test newStartOfServiceTimes[2] == 423 
    @test newStartOfServiceTimes[3] == 438 
    @test newStartOfServiceTimes[4] == 490
    @test newStartOfServiceTimes[5] == 490
    @test newStartOfServiceTimes[6] == 512
    @test newStartOfServiceTimes[7] == 563

    # Insert request 
    insertRequest!(request1,vehicleSchedule,4,4,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""
end



@testset "Check feasibility of insertion: W - P - D - ROUTE - W" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
    scenario.time[1,6] = 15
    scenario.time[11,4] = 40
    scenario.time[9,1] = 40

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 490 - scenario.time[vehicle.depotId,1]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[1]
    request2 = scenario.requests[4]

    # Insert request 2 
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
    @test feasible == true
    @test msg == ""

    # Inser pick up and drop off at beginning of schedule block 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request2,vehicleSchedule,1,1,scenario)
    @test feasible == true
    @test newStartOfServiceTimes[1] == 400 
    @test newStartOfServiceTimes[2] == 440 
    @test newStartOfServiceTimes[3] == 455 
    @test newStartOfServiceTimes[4] == 497
    @test newStartOfServiceTimes[5] == 514
    @test newStartOfServiceTimes[6] == 565
    @test newStartOfServiceTimes[7] == 565

    # Insert request
    insertRequest!(request2,vehicleSchedule,1,1,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""
end


@testset "Check feasibility of insertion: W - P - ROUTE- D - ROUTE - W" begin 
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
    startTime = 490 - scenario.time[vehicle.depotId,1]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[1]
    request1.pickUpActivity.timeWindow.startTime = 450
    request1.dropOffActivity.timeWindow.startTime = 460
    request2 = scenario.requests[4]
    request2.dropOffActivity.timeWindow.startTime = 460 
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

    # Infeasible ride time for request 1 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request2,vehicleSchedule,1,2,scenario)
    @test feasible == false 

    # Feasible 
    request1.maximumRideTime = 40 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request2,vehicleSchedule,1,2,scenario)
    @test feasible == true 
    @test newStartOfServiceTimes[1] == 410
    @test newStartOfServiceTimes[2] == 440 
    @test newStartOfServiceTimes[3] == 477 
    @test newStartOfServiceTimes[4] == 492
    @test newStartOfServiceTimes[5] == 508
    @test newStartOfServiceTimes[6] == 559
    @test newStartOfServiceTimes[7] == 559

    # Insert request
    insertRequest!(request2,vehicleSchedule,1,2,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""
end



@testset "Check feasibility of insertion: W - ROUTE - P - ROUTE- D - ROUTE - W" begin 
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
    startTime = 420 - scenario.time[vehicle.depotId,4]
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

    # Case where waiting node is added in between pick-up and drop-off 
    request1.requestType = PICKUP_REQUEST
    request1.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(421)
    request1.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    request1.maximumRideTime = findMaximumRideTime(request1.directDriveTime,200,1) 
    request1.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[2,7], request1.maximumRideTime)

    feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request1,vehicleSchedule,2,3,scenario)
    @test feasible == true 

    # Insert request
    insertRequest!(request1,vehicleSchedule,2,3,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""
end



@testset "Check feasibility of insertion: W  - P - ROUTE- D - ROUTE - W" begin 
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
    startTime = 490 - scenario.time[vehicle.depotId,1]
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
    @test feasible == true
    @test msg == ""

    # Case where pick up can be inserted by shifting route backwards and drop off can be inserted directly 
   feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request2,vehicleSchedule,1,3,scenario)
   @test feasible == true 

    # Insert request
    copyVehicleSchedule = deepcopy(vehicleSchedule)
    insertRequest!(request2,copyVehicleSchedule,1,3,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,copyVehicleSchedule)
    @test feasible == true
    @test msg == ""
end




@testset "Check feasibility of insertion: W - ROUTE - P - ROUTE- D  - W" begin 
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
    scenario.time[2,1] = 0
    scenario.time[1,2] = 0
    scenario.time[7,6] = 0
    scenario.time[6,7] = 0
    scenario.time[1,7] = 16
    scenario.time[7,1] = 16
    scenario.time[6,9] = 1
    scenario.time[9,6] = 1

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicle.totalCapacity = 4
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    # Update start depot 
    startTime = 420 - scenario.time[vehicle.depotId,4]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[2]
    request2 = scenario.requests[4]
    request3 = scenario.requests[1]

    # Insert request 2 
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request2.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes
    request2.maximumRideTime = findMaximumRideTime(request2.directDriveTime,2000,1) 

    startOfServiceDropOff = 444
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

    # Add another request
    request1.requestType = PICKUP_REQUEST
    request1.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(421)
    request1.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    request1.maximumRideTime = findMaximumRideTime(request1.directDriveTime,2000,1) 
    request1.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[2,7], request1.maximumRideTime)

    insert!(vehicleSchedule.route,3,ActivityAssignment(request1.pickUpActivity, vehicleSchedule.vehicle, 423, 425))
    insert!(vehicleSchedule.route,4,ActivityAssignment(request1.dropOffActivity, vehicleSchedule.vehicle, 441, 443))

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request2.pickUpActivity.id] + scenario.distance[request2.pickUpActivity.id,request1.pickUpActivity.id] + scenario.distance[request1.pickUpActivity.id,request1.dropOffActivity.id] + scenario.distance[request1.dropOffActivity.id,request2.dropOffActivity.id] + scenario.distance[request2.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id] + 10.0*(419 - 403)/scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,2,1,0,0,0]
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""

    # Add another request
    request3.requestType = PICKUP_REQUEST
    request3.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(426)
    request3.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    request3.maximumRideTime = findMaximumRideTime(request1.directDriveTime,2000,1) 
    request3.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[1,6], request1.maximumRideTime)

    feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request3,vehicleSchedule,3,5,scenario)
    @test feasible == true
    @test msg == ""

     # Insert request
    copyVehicleSchedule = deepcopy(vehicleSchedule)
    insertRequest!(request3,copyVehicleSchedule,3,5,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,copyVehicleSchedule)
    @test feasible == true
    @test msg == ""
end



@testset "Check feasibility of insertion: W - ROUTE - P - D - ROUTE - W" begin 
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
    scenario.time[2,1] = 1
    scenario.time[6,7] = 1
    scenario.time[1,6] = 15

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicle.totalCapacity = 4
    vehicleSchedule = VehicleSchedule(vehicle)

   #== Check feasible route ==#
    # Update start depot 
    startTime = 420 - scenario.time[vehicle.depotId,4]
    vehicleSchedule.route[1].startOfServiceTime = startTime
    vehicleSchedule.route[1].endOfServiceTime = startTime

    # Requests  
    request1 = scenario.requests[2]
    request2 = scenario.requests[4]
    request3 = scenario.requests[1]

    # Insert request 2 
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request2.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes
    request2.maximumRideTime = findMaximumRideTime(request2.directDriveTime,2000,1) 

    startOfServiceDropOff = 444
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

    # Add another request
    request1.requestType = PICKUP_REQUEST
    request1.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(421)
    request1.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    request1.maximumRideTime = findMaximumRideTime(request1.directDriveTime,2000,1) 
    request1.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[2,7], request1.maximumRideTime)

    insert!(vehicleSchedule.route,3,ActivityAssignment(request1.pickUpActivity, vehicleSchedule.vehicle, 423, 425))
    insert!(vehicleSchedule.route,4,ActivityAssignment(request1.dropOffActivity, vehicleSchedule.vehicle, 441, 443))

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request2.pickUpActivity.id] + scenario.distance[request2.pickUpActivity.id,request1.pickUpActivity.id] + scenario.distance[request1.pickUpActivity.id,request1.dropOffActivity.id] + scenario.distance[request1.dropOffActivity.id,request2.dropOffActivity.id] + scenario.distance[request2.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = 10.0*(startOfServiceDropOff - endOfServiceTimePickUp)/scenario.time[request2.pickUpActivity.id,request2.dropOffActivity.id] + 10.0*(419 - 403)/scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,2,1,0,0,0]
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    printRouteHorizontal(vehicleSchedule)

    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == true
    @test msg == ""

    # Add another request
    request3.requestType = PICKUP_REQUEST
    request3.pickUpActivity.timeWindow = findTimeWindowOfRequestedPickUpTime(426)
    request3.directDriveTime = scenario.time[request1.pickUpActivity.id,request1.dropOffActivity.id]
    scenario.time[request3.pickUpActivity.id,request3.dropOffActivity.id] = request3.directDriveTime
    request3.maximumRideTime = findMaximumRideTime(request1.directDriveTime,200,1) 
    request3.dropOffActivity.timeWindow = findTimeWindowOfDropOff(request1.pickUpActivity.timeWindow, scenario.time[1,6], request1.maximumRideTime)

    feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete = checkFeasibilityOfInsertionAtPosition(request3,vehicleSchedule,3,3,scenario)
    @test feasible == true

    # Insert request
    copyVehicleSchedule = deepcopy(vehicleSchedule)
    insertRequest!(request3,copyVehicleSchedule,3,3,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete)
    feasible, msg = checkRouteFeasibility(scenario,copyVehicleSchedule)
    @test feasible == true
    @test msg == ""
end


