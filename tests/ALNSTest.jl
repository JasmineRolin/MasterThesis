using Test 
using alns, domain, utils

#==
Test ALNSFunctions
==#
@testset "readALNSParameters test" begin 
    parametersFile = "tests/resources/ALNSParameters.json"

    # Read parameters 
    parameters = readALNSParameters(parametersFile)

    @test typeof(parameters) == ALNSParameters
    @test parameters.timeLimit == 10.0 
    @test parameters.reactionFactor == 0.01 
    @test parameters.startThreshold == 0.03 
    @test parameters.solCostEps == 0.0 
    @test parameters.scoreAccepted == 2.0 
    @test parameters.scoreImproved == 4.0 
    @test parameters.scoreNewBest == 10.0
end


@testset "rouletteWheel test" begin
    weights = Float64[1.0,3.4,5.0,9.3]

    idx = rouletteWheel(weights)

    @test idx > 0
    @test idx <= 4
end

@testset "calculateScore test" begin 
    parameters = ALNSParameters()

    # Not accepted, improved or new best
    score = calculateScore(parameters,false,false,false)
    @test score == 1.0

    # Accepted
    score = calculateScore(parameters,true,false,false)
    @test score == 2.0

    # Improved 
    score = calculateScore(parameters,true,true,false)
    @test score == 4.0

    # New best
    score = calculateScore(parameters,true,true,true)
    @test score == 10.0

end

@testset "addDestroyMethod! and addRepairMethod! test" begin 
   # create dummy methods 
   function dest1() return 1  end
   function dest2() return 1  end
   function rep1() return 1  end
   function rep2() return 1  end

   # Create configuration 
   # Parameters 
   parameters = ALNSParameters()
   configuration = ALNSConfiguration(parameters)
   addDestroyMethod!(configuration,"dest1",dest1)
   addDestroyMethod!(configuration,"dest2",dest2)
   addRepairMethod!(configuration,"rep1",rep1)
   addRepairMethod!(configuration,"rep2",rep2)

   @test length(configuration.destroyMethods) == 2
   @test length(configuration.repairMethods) == 2
   @test typeof(configuration.destroyMethods[1]) == GenericMethod
   @test configuration.destroyMethods[1].name == "dest1"
   @test configuration.repairMethods[2].name == "rep2"

end 


@testset "updateWeights! test" begin 
    # create dummy methods 
    function dest1() return 1  end
    function dest2() return 1  end
    function rep1() return 1  end
    function rep2() return 1  end

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)
    addDestroyMethod!(configuration,"dest1",dest1)
    addDestroyMethod!(configuration,"dest2",dest2)
    addRepairMethod!(configuration,"rep1",rep1)
    addRepairMethod!(configuration,"rep2",rep2)

    # Create state 
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,1,depotLocation,80,capacities,8)

    # Activitys 
    location = Location("PU",10.0,10.0)
    timeWindow = TimeWindow(90,100)
    activity = Activity(1,0,PICKUP,WALKING,location,timeWindow)

    # RequestAssignment
    activityAssignment = ActivityAssignment(activity,vehicle,8,7,WALKING)

    # VehicleSchedule
    route = [activityAssignment]
    vehicleSchedule = VehicleSchedule(vehicle)

    # Solution 
    solution = Solution([vehicleSchedule],70.0,4,5,2,4)
    
    state = ALNSState(Float64[2.0,3.5],Float64[1.0,3.0],[1,2],[2,0],solution,solution,Vector{Int}(),Vector{Int}())

    # Update weights 
    updateWeights!(state,configuration,2,1,true,true,false)

    @test state.destroyWeights[1] == 2.0 
    @test state.destroyWeights[2] == 3.5*(1-0.01) + 0.01*(4.0/2.0)
    
    @test state.repairWeights[1] == 1.0*(1-0.01) + 0.01*(4.0/2.0) 
    @test state.repairWeights[2] == 3.0

end  


@testset "destroy! and repair! test" begin
    # Dummy methods
    function dest1(scenario::Scenario,state::ALNSState,parameters::ALNSParameters)
        solution.totalCost = 900       
    end
    function rep1(solution::Solution,parameters::ALNSParameters)
        solution.totalCost = 500        
    end

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)
    addDestroyMethod!(configuration,"dest1",dest1)
    addRepairMethod!(configuration,"rep1",rep1)

    # Create state 
    # Vehicle 
    depotLocation = Location("depot",10,10)
    timeWindow = TimeWindow(900,980)

    capacities = Dict{MobilityType, Int}(WALKING => 3, WHEELCHAIR => 5)

    vehicle = Vehicle(0,timeWindow,1,depotLocation,80,capacities,8)

    # Activitys 
    location = Location("PU",10.0,10.0)
    timeWindow = TimeWindow(90,100)
    activity = Activity(1,0,PICKUP,WALKING,location,timeWindow)

    # RequestAssignment
    activityAssignment = ActivityAssignment(activity,vehicle,8,7,WALKING)

    # VehicleSchedule
    route = [activityAssignment]
    vehicleSchedule = VehicleSchedule(vehicle)

    # Solution 
    solution = Solution([vehicleSchedule],70.0,4,5,2,4)
    
    state = ALNSState(Float64[2.0],Float64[3.0],[1],[2],solution,solution,Vector{Int}(),Vector{Int}())

    # Destroy 
    destroyIdx = destroy!(Scenario(),state,parameters,configuration)
    @test destroyIdx == 1
    @test state.destroyNumberOfUses[1] == 2
    @test solution.totalCost == 900 

    # Repair 
    repairIdx = repair!(configuration,parameters,state,solution)
    @test repairIdx == 1
    @test state.repairNumberOfUses[1] == 3
    @test solution.totalCost == 500 

end


# @testset "Greedy Repair test" begin

#     # Create configuration 
#     # Parameters 
#     parameters = ALNSParameters()
#     configuration = ALNSConfiguration(parameters)


#     # Create route
#     requestFile = "tests/resources/RequestsRepair.csv"
#     vehiclesFile = "tests/resources/Vehicles.csv"
#     parametersFile = "tests/resources/Parameters.csv"
#     distanceMatrixFile = "tests/resources/distanceMatrix_Small.txt"
#     timeMatrixFile = "tests/resources/timeMatrix_Small.txt"

#     # Read instance 
#     scenario = readInstance(requestFile,vehiclesFile,parametersFile,distanceMatrixFile,timeMatrixFile)

#     # Create VehicleSchedule
#     vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

#     # Insert request
#     insertRequest!(scenario.requests[1],vehicleSchedule,1,1,WALKING,scenario)

#     # Create requestBank
#     requestBank = [2]


#     # Solution 
#     solution = Solution([vehicleSchedule],70.0,4,5,2,4)

#     # Make ALNS state
#     state = ALNSState(Float64[2.0],Float64[3.0],[1],[2],solution,solution,requestBank,Vector{Int}())

#     # Greedy repair 
#     newSolution = greedyInsertion(state,scenario)

#     feasible, msg = checkRouteFeasibility(scenario, newSolution.vehicleSchedules[1])
#     @test feasible == true


# end


#==
@testset "Regret Repair test" begin

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)


    # Create route
    requestFile = "tests/resources/RequestsRepair.csv"
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

    # Create requestBank
    requestBank = [2]



    # Solution 
    solution = Solution([vehicleSchedule],70.0,4,5,2,4)
    printRoute(solution.vehicleSchedules[1])

    # Make ALNS state
    state = ALNSState(Float64[2.0],Float64[3.0],[1],[2],solution,solution,requestBank)

    # Greedy repair 
    newSolution = regretInsertion(state,scenario)
    printRoute(newSolution.vehicleSchedules[1])

    feasible, msg = checkRouteFeasibility(scenario, newSolution.vehicleSchedules[1])
    @test feasible == true


end
==#
