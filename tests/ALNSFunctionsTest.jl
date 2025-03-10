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
    @test parameters.timeLimit == 100.0 
    @test parameters.printSegmentSize == 100
    @test parameters.segmentSize == 100
    @test parameters.w == 0.05
    @test parameters.coolingRate == 0.99975
    @test parameters.reactionFactor == 0.01 
    @test parameters.scoreAccepted == 2.0 
    @test parameters.scoreImproved == 4.0 
    @test parameters.scoreNewBest == 10.0
    @test parameters.minPercentToDestroy == 0.1
    @test parameters.maxPercentToDestroy == 0.3
    @test parameters.p == 6.0
    @test parameters.shawRemovalPhi == 9.0
    @test parameters.shawRemovalXi == 3.0
end


@testset "rouletteWheel test" begin
    weights = Float64[1.0,3.4,5.0,9.3]

    idx = rouletteWheel(weights)

    @test idx > 0
    @test idx <= 4
end

@testset "calculateScore test" begin 
    parameters = ALNSParameters()

    scoreAccepted = parameters.scoreAccepted
    scoreImproved = parameters.scoreImproved
    scoreNewBest = parameters.scoreNewBest

    # Not accepted, improved or new best
    score = calculateScore(scoreAccepted,scoreImproved,scoreNewBest,false,false,false)
    @test score == 1.0

    # Accepted
    score = calculateScore(scoreAccepted,scoreImproved,scoreNewBest,true,false,false)
    @test score == 2.0

    # Improved 
    score = calculateScore(scoreAccepted,scoreImproved,scoreNewBest,true,true,false)
    @test score == 4.0

    # New best
    score = calculateScore(scoreAccepted,scoreImproved,scoreNewBest,true,true,true)
    @test score == 10.0

end

@testset "aaddMethod! test" begin 
   # create dummy methods 
   function dest1() return 1  end
   function dest2() return 1  end

   # Create methods  
   methods = Vector{GenericMethod}()
   addMethod!(methods,"dest1",dest1)
   addMethod!(methods,"dest2",dest2)

   @test length(methods) == 2
   @test typeof(methods[1]) == GenericMethod
   @test typeof(methods[2]) == GenericMethod
   @test methods[1].name == "dest1"
   @test methods[2].name == "dest2"

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
    addMethod!(configuration.destroyMethods,"dest1",dest1)
    addMethod!(configuration.destroyMethods,"dest2",dest2)
    addMethod!(configuration.repairMethods,"rep1",rep1)
    addMethod!(configuration.repairMethods,"rep2",rep2)

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
    
    state = ALNSState(Float64[2.0,3.5],Float64[1.0,3.0],[1.0,4.0],[4.0,1.0],[1,2],[2,0],solution,solution,Vector{Int}(),Vector{Int}(),0)

    # Update weights 
    updateWeights!(state.destroyWeights,state.destroyScores,state.destroyNumberOfUses,parameters.reactionFactor)
    updateWeights!(state.repairWeights,state.repairScores,state.repairNumberOfUses,parameters.reactionFactor)

    @test state.destroyWeights[1] == 2.0*(1-0.01) + 0.01*(1.0/1) 
    @test state.destroyWeights[2] == 3.5*(1-0.01) + 0.01*(4.0/2.0)
    
    @test state.repairWeights[1] == 1.0*(1-0.01) + 0.01*(4.0/2.0) 
    @test state.repairWeights[2] == 3.0

end  


@testset "destroy! and repair! test" begin
    # Dummy methods
    function dest1(scenario::Scenario,state::ALNSState,parameters::ALNSParameters)
        solution.totalCost = 900       
    end
    function rep1(state::ALNSState,scenario::Scenario)
        state.currentSolution.totalCost = 500        
    end

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)
    addMethod!(configuration.destroyMethods,"dest1",dest1)
    addMethod!(configuration.repairMethods,"rep1",rep1)

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
    
    state = ALNSState(Float64[2.0],Float64[3.0],[1.0],[1.0],[1],[2],solution,solution,Vector{Int}(),Vector{Int}(),0)

    # Destroy 
    destroyIdx = destroy!(Scenario(),state,parameters,configuration)
    @test destroyIdx == 1
    @test solution.totalCost == 900 

    # Repair 
    repairIdx = repair!(Scenario(),state,configuration)
    @test repairIdx == 1
    @test state.currentSolution.totalCost == 500 

end


@testset "findStartTemperature test" begin 
    # create dummy methods 
    function dest1() return 1  end
    function dest2() return 1  end
    function rep1() return 1  end
    function rep2() return 1  end

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)
    addMethod!(configuration.destroyMethods,"dest1",dest1)
    addMethod!(configuration.destroyMethods,"dest2",dest2)
    addMethod!(configuration.repairMethods,"rep1",rep1)
    addMethod!(configuration.repairMethods,"rep2",rep2)

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
    
    # Update weights 
    startTemperature = findStartTemperature(parameters.w,solution)
    @test isapprox(startTemperature,5.0497763)
end  

@testset "updateWeightsAfterEndOfSegment test" begin 
    # create dummy methods 
    function dest1() return 1  end
    function dest2() return 1  end
    function rep1() return 1  end
    function rep2() return 1  end

    # Create configuration 
    # Parameters 
    parameters = ALNSParameters()
    configuration = ALNSConfiguration(parameters)
    addMethod!(configuration.destroyMethods,"dest1",dest1)
    addMethod!(configuration.destroyMethods,"dest2",dest2)
    addMethod!(configuration.repairMethods,"rep1",rep1)
    addMethod!(configuration.repairMethods,"rep2",rep2)

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
    
    state = ALNSState(Float64[2.0,3.5],Float64[1.0,3.0],[1.0,4.0],[4.0,1.0],[1,2],[2,0],solution,solution,Vector{Int}(),Vector{Int}(),0)

    # Update before end of segment 
    updateWeightsAfterEndOfSegment(parameters.segmentSize,state,parameters.reactionFactor,3)

    @test state.destroyWeights[1] == 2.0
    @test state.destroyWeights[2] == 3.5
    @test state.destroyScores[1] == 1.0
    @test state.destroyScores[2] == 4.0
    @test state.destroyNumberOfUses[1] == 1
    @test state.destroyNumberOfUses[2] == 2
    
    @test state.repairWeights[1] == 1.0
    @test state.repairWeights[2] == 3.0
    @test state.repairScores[1] == 4.0
    @test state.repairScores[2] == 1.0
    @test state.repairNumberOfUses[1] == 2
    @test state.repairNumberOfUses[2] == 0

    # Update at end of segment 
    updateWeightsAfterEndOfSegment(parameters.segmentSize,state,parameters.reactionFactor,20)

    @test state.destroyWeights[1] == 2.0*(1-0.01) + 0.01*(1.0/1) 
    @test state.destroyWeights[2] == 3.5*(1-0.01) + 0.01*(4.0/2.0)
    @test state.destroyScores[1] == 0
    @test state.destroyScores[2] == 0
    @test state.destroyNumberOfUses[1] == 0
    @test state.destroyNumberOfUses[2] == 0
    
    @test state.repairWeights[1] == 1.0*(1-0.01) + 0.01*(4.0/2.0) 
    @test state.repairWeights[2] == 3.0
    @test state.repairScores[1] == 0.0
    @test state.repairScores[2] == 0.0
    @test state.repairNumberOfUses[1] == 0
    @test state.repairNumberOfUses[2] == 0

end  
