using Test 
using alns, domain, utils, offlinesolution

@testset "Greedy Repair test" begin

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
    scenarioName = "Small"

    # Read instance 
    scenario = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)

    # Create VehicleSchedule
    vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

    # Insert request
    newStartOfServiceTimes = [428,476,480,1380]
    newEndOfServiceTimes = [428,478,482,1380]
    insertRequest!(scenario.requests[1],vehicleSchedule,1,1,scenario,newStartOfServiceTimes,newEndOfServiceTimes,Vector{Int}())

    # Create requestBank
    requestBank = [2,3,4]
    assignedRequests = [1]
    nAssignedRequests = 1

    # Solution 
    solution = Solution([vehicleSchedule],10.0 + 3*scenario.taxiParameter,3,5,2.0,4)

    # Make ALNS state
    alnsState = ALNSState(Float64[2.0,3.5,2.0],Float64[1.0,3.0],[1.0,4.0,1.0],[4.0,1.0],[1,2,1],[2,0],solution,requestBank,solution,requestBank,assignedRequests,nAssignedRequests)

    # Greedy repair 
    greedyInsertion(alnsState,scenario)

    #printRouteHorizontal(alnsState.currentSolution.vehicleSchedules[1])

    state = State(solution,Request(),0)
    feasible, msg = checkRouteFeasibilityOnline(scenario,vehicleSchedule,state.visitedRoute)
    if !feasible
        println(msg)
    end
    @test feasible == true
    @test msg == ""
end




@testset "Regret Repair test" begin

   # Create configuration 
   # Parameters 
   parameters = ALNSParameters()
   configuration = ALNSConfiguration(parameters)


   # Create route
   requestFile = "tests/resources/RequestsRepair.csv"
   vehiclesFile = "tests/resources/Vehicles.csv"
   parametersFile = "tests/resources/Parameters.csv"
   distanceMatrixFile = "Data/Matrices/Konsentra_Data_distance.txt"
   timeMatrixFile = "Data/Matrices/Konsentra_Data_time.txt"
   alnsParametersFile = "tests/resources/ALNSParameters.json"
   scenarioName = "Konsentra"

   # Read instance 
   scenario2 = readInstance(requestFile,vehiclesFile,parametersFile,scenarioName,distanceMatrixFile,timeMatrixFile)
   scenario = Scenario(scenarioName,scenario2.requests,scenario2.onlineRequests,scenario2.offlineRequests,scenario2.serviceTimes,[scenario2.vehicles[1]],scenario2.vehicleCostPrHour,scenario2.vehicleStartUpCost,scenario2.planningPeriod,scenario2.bufferTime,scenario2.maximumDriveTimePercent,scenario2.minimumMaximumDriveTime,scenario2.distance,scenario2.time,scenario2.nDepots,scenario2.depots,scenario2.taxiParameter)

   # Create VehicleSchedule
   vehicleSchedule = VehicleSchedule(scenario.vehicles[1])

   # Insert request
   newStartOfServiceTimes = [428,476,480,1380]
   newEndOfServiceTimes = [428,478,482,1380]
   insertRequest!(scenario.requests[1],vehicleSchedule,1,1,scenario,newStartOfServiceTimes,newEndOfServiceTimes,Vector{Int}())

   # Choose destroy methods
   destroyMethods = Vector{GenericMethod}()
   addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
   addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
   addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

   # Choose repair methods
   repairMethods = Vector{GenericMethod}()
   addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
   addMethod!(repairMethods,"regretInsertion",regretInsertion)

   # Create requestBank
   requestBank = [2,3,4]
   assignedRequests = [1]
   nAssignedRequests = 1

   # Solution 
   solution = Solution([vehicleSchedule],10.0 + 3*scenario.taxiParameter,3,5,2.0,4)

   # Make ALNS state
   alnsState = ALNSState(Float64[2.0,3.5,2.0],Float64[1.0,3.0],[1.0,4.0,1.0],[4.0,1.0],[1,2,1],[2,0],solution,requestBank,solution,requestBank,assignedRequests,nAssignedRequests)

   # Regret repair 
   regretInsertion(alnsState,scenario)

   state = State(solution,Request(),1)
   feasible, msg =  checkRouteFeasibilityOnline(scenario,vehicleSchedule,state.visitedRoute)
   @test feasible == true
   @test msg == ""
end