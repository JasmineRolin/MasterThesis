using Test 
using Dates
using domain 
using utils

#==
 Test all domain modules
==#

#==
 Test Location 
==#
@testset "Location test" begin
    location = Location("test",1.0,1.0)

    # Tests
    @test typeof(location) == Location
    @test location.name == "test"
end


#==
 Test time window  
==#
@testset "TimeWindow test" begin
    tw = TimeWindow(8*60,8*60+45)

    # Tests
    @test typeof(tw) == TimeWindow
    @test duration(tw) == 45
end


#==
 Test request
==#
@testset "Request test" begin
    pickUpLocation = Location("PU",10.0,10.0)
    dropOffLocation = Location("DO",10.0,10.0)

    pickUpTimeWindow = TimeWindow(90,100)
    dropOffTimeWindow = TimeWindow(900,980)

    pickUpActivity = Activity(1,0,PICKUP,WALKING,pickUpLocation,pickUpTimeWindow)
    dropOffActivity = Activity(1,0,PICKUP,WALKING,dropOffLocation,dropOffTimeWindow)

    request = Request(0,PICKUP_REQUEST,WALKING,500,pickUpActivity,dropOffActivity,10,100)

    # Tests
    @test typeof(request) == Request
end


#==
 Test vehicle
==#
@testset "vehicle test" begin
    depotLocation = Location("depot",10.0,10.0)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,1,depotLocation,80,capacities,8)

    # Tests
    @test typeof(vehicle) == Vehicle
end


#==
 Test ActivityAssignment
==#
@testset "ActivityAssignment test" begin
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,1,depotLocation,80,capacities,8)

    # Activitys 
    location = Location("PU",10.0,10.0)
    timeWindow = TimeWindow(90,100)
    activity = Activity(1,0,PICKUP,WALKING,location,timeWindow)
    mobilityAssignment = WALKING

    # RequestAssignment
    activityAssignment = ActivityAssignment(activity,vehicle,8,7,mobilityAssignment)

    # Tests
    @test typeof(activityAssignment) == ActivityAssignment
end



#==
 Test VehicleSchedule
==#
@testset "VehicleSchedule test" begin
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,1,depotLocation,80,capacities,8)

    vehicleSchedule = VehicleSchedule(vehicle)

    # Tests
    @test typeof(vehicleSchedule) == VehicleSchedule
end




#==
 Test Solution
==#
@testset "Solution test" begin
    requestFile = "tests/resources/Requests.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
    timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

    # Solution 
    solution = Solution(scenario)

    # Tests
    @test typeof(solution) == Solution
end
