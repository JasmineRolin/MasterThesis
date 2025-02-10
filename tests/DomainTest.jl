using Test 
using Dates
using domain 

#==
 Test all domain modules
==#

#==
 Test Location 
==#
@testset "Location test" begin
    location = Location("test",1,1)

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
    pickUpLocation = Location("PU",10,10)
    dropOffLocation = Location("DO",10,10)

    pickUpTimeWindow = TimeWindow(90,100)
    dropOffTimeWindow = TimeWindow(900,980)

    request = Request(0,PICKUP,WALKING,1,500,pickUpLocation,dropOffLocation,pickUpTimeWindow,dropOffTimeWindow,100)

    # Tests
    @test typeof(request) == Request
end


#==
 Test vehicle
==#
@testset "vehicle test" begin
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,depotLocation,80,capacities,8)

    # Tests
    @test typeof(vehicle) == Vehicle
end


#==
 Test RequestAssignment
==#
@testset "RequestAssignment test" begin
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,depotLocation,80,capacities,8)

    # Request 
    pickUpLocation = Location("PU",10,10)
    dropOffLocation = Location("DO",10,10)

    pickUpTimeWindow = TimeWindow(90,100)
    dropOffTimeWindow = TimeWindow(900,980)

    request = Request(0,PICKUP,WALKING,1,500,pickUpLocation,dropOffLocation,pickUpTimeWindow,dropOffTimeWindow,100)

    # RequestAssignment
    requestAssignment = RequestAssignment(request,vehicle,8,7)

    # Tests
    @test typeof(requestAssignment) == RequestAssignment
end



#==
 Test VehicleSchedule
==#
@testset "VehicleSchedule test" begin
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,depotLocation,80,capacities,8)

    # Request 
    pickUpLocation = Location("PU",10,10)
    dropOffLocation = Location("DO",10,10)

    pickUpTimeWindow = TimeWindow(90,100)
    dropOffTimeWindow = TimeWindow(900,980)

    request = Request(0,PICKUP,WALKING,1,500,pickUpLocation,dropOffLocation,pickUpTimeWindow,dropOffTimeWindow,100)

    # RequestAssignment
    requestAssignment = RequestAssignment(request,vehicle,8,7)

    # VehicleSchedule
    route = [requestAssignment]
    vehicleSchedule = VehicleSchedule(vehicle,route,timeWindow,40,40)

    # Tests
    @test typeof(vehicleSchedule) == VehicleSchedule
end




#==
 Test Solution
==#
@testset "Solution test" begin
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,depotLocation,80,capacities,8)

    # Request 
    pickUpLocation = Location("PU",10,10)
    dropOffLocation = Location("DO",10,10)

    pickUpTimeWindow = TimeWindow(90,100)
    dropOffTimeWindow = TimeWindow(900,980)

    request = Request(0,PICKUP,WALKING,1,500,pickUpLocation,dropOffLocation,pickUpTimeWindow,dropOffTimeWindow,100)

    # RequestAssignment
    requestAssignment = RequestAssignment(request,vehicle,8,7)

    # VehicleSchedule
    route = [requestAssignment]
    vehicleSchedule = VehicleSchedule(vehicle,route,timeWindow,40,40)

    # Solution 
    solution = Solution([vehicleSchedule],70)

    # Tests
    @test typeof(solution) == Solution
end
