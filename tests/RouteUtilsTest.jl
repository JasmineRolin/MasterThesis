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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

    # Insert request
    insertRequest!(scenario.requests[1],vehicleSchedule,1,1,WALKING,scenario)

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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

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
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes[request.pickUpActivity.mobilityType]

    startOfServiceDropOff = 16 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes[request.dropOffActivity.mobilityType]

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp,WALKING)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff,WALKING)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,WALKING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,4,waitingActivity)

    startOfServiceWaiting = route[2].endOfServiceTime 
    endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,WALKING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,3,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = ((startOfServiceDropOff - endOfServiceTimePickUp ) - scenario.time[request.pickUpActivity.id,request.dropOffActivity.id])/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,1,0,0,0]
    vehicleSchedule.numberOfWheelchair = [0,0,0,0,0,0]

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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicle = scenario.vehicles[1]
    vehicleSchedule = VehicleSchedule(vehicle)

    #== Check feasible route ==#
    startTime = 415
    vehicleSchedule.route[1].startOfServiceTime = 0
    vehicleSchedule.route[1].endOfServiceTime = 0

    request = scenario.requests[1]
    startOfServicePickUp = startTime + scenario.time[vehicle.depotId,request.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes[request.pickUpActivity.mobilityType]

    startOfServiceDropOff = 16 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes[request.dropOffActivity.mobilityType]

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp,WALKING)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff,WALKING)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,WALKING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,4,waitingActivity)
    
    startOfServiceWaiting = route[2].endOfServiceTime 
    endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,WALKING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,3,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = (startOfServiceDropOff - endOfServiceTimePickUp ) - scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,1,0,0,0]
    vehicleSchedule.numberOfWheelchair = [0,0,0,0,0,0]

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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

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
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes[request.pickUpActivity.mobilityType]

    startOfServiceDropOff =  endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes[request.dropOffActivity.mobilityType]

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp,WALKING)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff,WALKING)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,WALKING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,4,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = ((startOfServiceDropOff - endOfServiceTimePickUp ) - scenario.time[request.pickUpActivity.id,request.dropOffActivity.id])/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    vehicleSchedule.numberOfWheelchair = [0,0,0,0,0]

    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == false
    @test msg == "ROUTE INFEASIBLE: Time window not respected for activity 6 on vehicle 1, Start/End of Service: (467, 469), Time Window: (480, 500)"
   

end

@testset "routeFeasibility test - dropoff before pickup" begin 
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

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
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes[request.pickUpActivity.mobilityType]

    startOfServiceDropOff =  endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes[request.dropOffActivity.mobilityType]

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp,WALKING)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff,WALKING)

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
    vehicleSchedule.totalCost = ((startOfServiceDropOff - endOfServiceTimePickUp ) - scenario.time[request.pickUpActivity.id,request.dropOffActivity.id])/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,0,1,0]
    vehicleSchedule.numberOfWheelchair = [0,0,0,0]

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

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

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
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes[request.pickUpActivity.mobilityType]

    startOfServiceDropOff =  25 + endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes[request.dropOffActivity.mobilityType]

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp,WALKING)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff,WALKING)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)
    

    # Insert waiting nodes
    route = vehicleSchedule.route
    startOfServiceWaiting = route[3].endOfServiceTime 
    endOfServiceWaiting = route[4].startOfServiceTime - scenario.time[route[3].activity.id,route[4].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[3].activity.id,-1,WAITING,WALKING,route[3].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,4,waitingActivity)

    startOfServiceWaiting = route[2].endOfServiceTime 
    endOfServiceWaiting = route[3].startOfServiceTime - scenario.time[route[2].activity.id,route[3].activity.id]
    waitingActivity = ActivityAssignment(Activity(route[2].activity.id,-1,WAITING,WALKING,route[2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
    insert!(vehicleSchedule.route,3,waitingActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = startTime
    vehicleSchedule.activeTimeWindow.endTime = route[end-1].endOfServiceTime + scenario.time[route[end-1].activity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)
    vehicleSchedule.totalCost = ((startOfServiceDropOff - endOfServiceTimePickUp ) - scenario.time[request.pickUpActivity.id,request.dropOffActivity.id])/scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    vehicleSchedule.numberOfWalking = [0,1,0,0,0]
    vehicleSchedule.numberOfWheelchair = [0,0,0,0,0]

    # Check route feasibility
    feasible, msg = checkRouteFeasibility(scenario,vehicleSchedule)
    @test feasible == false
    @test msg == "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off 6 on vehicle 1"
   

end