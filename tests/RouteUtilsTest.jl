using Test 
using utils 
using domain 

#==
 Test printVehicleSchedule
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
    insertRequest!(scenario.requests[1],vehicleSchedule,2,2,scenario)

    printRoute(vehicleSchedule)

end 


#==
 Test routeFeasibility
==#
@testset "routeFeasibility test" begin 
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

    # Insert request
    request = scenario.requests[1]
    startOfServicePickUp = scenario.time[vehicle.depotId,requests.pickUpActivity.id] 
    endOfServiceTimePickUp = startOfServicePickUp + scenario.serviceTimes[request.pickUpActivity.mobilityType]

    startOfServiceDropOff = endOfServiceTimePickUp + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id]
    endOfServiceTimeDropOff = startOfServiceDropOff + scenario.serviceTimes[request.dropOffActivity.mobilityType]

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePickUp, endOfServiceTimePickUp)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDropOff, endOfServiceTimeDropOff)

    insert!(vehicleSchedule.route,2,pickUpActivity)
    insert!(vehicleSchedule.route,3,dropOffActivity)

    # Update vehicle schedule
    vehicleSchedule.activeTimeWindow.startTime = 0 
    vehicleSchedule.activeTimeWindow.endTime = dropOffActivity.endOfServiceTime + scenario.time[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.totalDistance = scenario.distance[vehicle.depotId,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicle.depotId]
    vehicleSchedule.numberOfWalking = [0,1,0,0]
    vehicleSchedule.numberOfWheelchair = [0,0,0,0]

    # Check route feasibility
    printRoute(vehicleSchedule)
    @test checkRouteFeasibility(scenario,vehicleSchedule) == true

end