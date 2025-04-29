using offlinesolution
using domain
using utils
using DataFrames
using CSV
using alns
using Test
using TimerOutputs

include("../dataexploration/GenerateLargeDataSets.jl")

function createExpectedRequests(N::Int,nFixedRequests::Int)
    
    # Initialize variables
    expectedRequests = Vector{Request}(undef, N)
    expectedRequestIds = Vector{Int}(undef, N)
    requestDF = DataFrame(
        id = Int[],
        pickup_latitude = Float64[],
        pickup_longitude = Float64[],
        dropoff_latitude = Float64[],
        dropoff_longitude = Float64[],
        request_type = Int[],
        request_time = Int[],
        mobility_type = String[],
        call_time = Int[],
        direct_drive_time = Int[],
    )

    probabilities_pickUpTime,probabilities_dropOffTime,_,_,probabilities_location,_,x_range,y_range,probabilities_distance,_,distance_range,_,_,_,_,_= load_simulation_data("Data/Simulation data/")
    time_range = collect(range(6*60,23*60))

    # Generate expected request DF
    for i in 1:N
        # Sample new location based on KDE probabilities
        sampled_location = getNewLocations(probabilities_location, x_range, y_range, distance_range,probabilities_distance)
        pickup_longitude, pickup_latitude = sampled_location[1]
        dropoff_longitude, dropoff_latitude = sampled_location[2]


        # Determine type of request
        if rand() < 0.5
            requestType = 0  # pick-up request

            sampled_indices = sample(1:length(probabilities_pickUpTime), Weights(probabilities_pickUpTime), 1)
            sampledTimePick = time_range[sampled_indices]
            requestTime = ceil(sampledTimePick[1])
        else
            requestType = 1  # drop-off request

            # Direct drive time 
            directDriveTime = ceil(haversine_distance(pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude)[2])

            # Earliest request time 
            earliestRequestTime = serviceWindow[1] + directDriveTime + MAX_DELAY
            indices = time_range .>= earliestRequestTime
            nTimes = sum(indices)

            sampled_indices = sample(1:nTimes, Weights(probabilities_dropOffTime[indices]), 1)
            sampledTimeDrop = time_range[indices][sampled_indices]
            requestTime = ceil(sampledTimeDrop[1])
        end

        push!(requestDF, (i, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, requestType, requestTime,"WALKING",0,0))
        append!(expectedRequestIds, i+nFixedRequests)
        
    
    end

    return requestDF

end

function getDistanceAndTimeMatrixFromDataFrame(requestsDf::DataFrame,expectedRequestsDf::DataFrame,depotLocations::Vector{Tuple{Float64,Float64}})::Tuple{Array{Float64, 2}, Array{Int, 2}}
    # Collect request info 
    pickUpLocations = [(r.pickup_latitude,r.pickup_longitude) for r in eachrow(requestsDf)]
    dropOffLocations = [(r.dropoff_latitude,r.dropoff_longitude)  for r in eachrow(requestsDf)]

    # Collect expected request info
    expectedPickUpLocations = [(r.pickup_latitude,r.pickup_longitude) for r in eachrow(expectedRequestsDf)]
    expectedDropOffLocations = [(r.dropoff_latitude,r.dropoff_longitude)  for r in eachrow(expectedRequestsDf)]

    # Collect all locations
    locations = [pickUpLocations;expectedPickUpLocations;dropOffLocations;expectedDropOffLocations;depotLocations]

    return getDistanceAndTimeMatrixFromLocations(locations)
end


function readInstanceAnticipation(requestFile::String, nExpected::Int, vehicleFile::String, parametersFile::String,scenarioName=""::String)

    # Check that files exist 
    if !isfile(requestFile)
        error("Error: Request file $requestFile does not exist.")
    end
    if !isfile(vehicleFile)
        error("Error: Vehicle file $vehicleFile does not exist.")
    end
    if !isfile(parametersFile)
        error("Error: Parameters file $parametersFile does not exist.")
    end
   

    # Read request, vehicle and parameters dataframes from input
    requestsDf = CSV.read(requestFile, DataFrame)
    vehiclesDf = CSV.read(vehicleFile, DataFrame)
    parametersDf = CSV.read(parametersFile, DataFrame)
    nRequests = nrow(requestsDf)
    
    # Get parameters 
    planningPeriod = TimeWindow(parametersDf[1,"start_of_planning_period"],parametersDf[1,"end_of_planning_period"])
    serviceTimes = parametersDf[1,"service_time_walking"]
    vehicleCostPrHour = Float64(parametersDf[1,"vehicle_cost_pr_hour"])
    vehicleStartUpCost = Float64(parametersDf[1,"vehicle_start_up_cost"])
    bufferTime = parametersDf[1,"buffer_time"]
    maximumRideTimePercent = parametersDf[1,"maximum_ride_time_percent"]
    minimumMaximumRideTime = parametersDf[1,"minimum_maximum_ride_time"]
    taxiParameter = Float64(parametersDf[1,"taxi_parameter"])
    

    # Get vehicles 
    vehicles,depots, depotLocations = readVehicles(vehiclesDf,nRequests)
    nDepots = length(depots)

    # Generate expected requests
    expectedRequestsDf = createExpectedRequests(nExpected,nRequests)

    # Read time and distance matrices from input or initialize empty matrices
    distance, time = getDistanceAndTimeMatrixFromDataFrame(requestsDf,expectedRequestsDf,collect(keys(depotLocations)))

    # Get requests 
    requests = readRequests(requestsDf,nRequests+nExpected,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time)
    expectedRequests = readRequests(expectedRequestsDf,nExpected,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,time,extraN=nRequests)
    allRequests = vcat(requests, expectedRequests)

    # Split into offline and online requests
    onlineRequests, offlineRequests = splitRequests(requests)

    # Get distance and time matrix
    scenario = Scenario(scenarioName,allRequests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,distance,time,nDepots,depots,taxiParameter)

    return scenario, nRequests

end


function removeExpectedRequestsFromSolution!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},solution::Solution,nExpected::Int,nFixed::Int;visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}(),scenario::Scenario=Scenario(),TO::TimerOutput=TimerOutput())
    
    # Determine remaining requests to remove
    requestsToRemove = Set{Int}()
    for i in nFixed+1:nFixed+nExpected
        if i in requestBank
            continue
        end
        # Add to remaining requests
        push!(requestsToRemove, i)
    end

    println("Length of requests to remove: ", length(requestsToRemove))

    # Choice of removal of activity
    remover = removeExpectedActivityFromRouteBasic!
    removeRequestsFromSolution!(time,distance,serviceTimes,requests,solution,requestsToRemove,remover=remover)

end

function removeExpectedActivityFromRouteBasic!(time::Array{Int,2},schedule::VehicleSchedule,idx::Int)

    # TODO: needs to be updated when waiting strategies are implemented 

    # Retrieve activities before and after activity to remove
    route = schedule.route
    currentActivity = route[idx]

    # How much did the route length reduce 
    routeReduction = 0

    currentActivity.activity.activityType = WAITING
    currentActivity.activity.timeWindow.startTime = currentActivity.startOfServiceTime
    currentActivity.activity.timeWindow.endTime = currentActivity.endOfServiceTime

    return routeReduction

end


#==
function offlineSolutionWithAnticipation(fixedRequests::Vector{Request},N::Int,scenario::Scenario,parameterFile::String)

    bestAverageSAE = maximumFloat64
    bestSolution = Solution()
    nFixedRequests = length(fixedRequests)

    for n in 1:10
        # Get values
        serviceTimes = scenario.serviceTimes
        distance = scenario.distance
        time = scenario.time
        requests = scenario.requests

        # Generate expected requests
        expectedRequests, expectedRequestIds  = generateExpectedRequests(N,nFixedRequests,parametersFile)         
        allRequests = vcat(fixedRequests, expectedRequests)

        # Update time and distance matrices
        time, distance = updateTimeAndDistanceMatrices(time,distance,allRequests) # Should be made in fastest possible way

        # Generate route
        solution, requestBank = runModifiedALNS(scenario,allRequests) # We only want solutions where all fixed requests are in. Expected does not need to be in. Need different weights for fixed and expected, so as many fixed as possible is in the route, so I think we need to use ALNS here. 

        # Remove expected requests
        removeRequestsFromSolution!(time,distance,serviceTimes,requests,solution,expectedRequestIds,scenario::Scenario=Scenario()) # WHich requests?, hvorfor er standard at scenario er tom? # Skal laves om, skal ikke fjerne waiting nodes, men indsætte istedet for kunder, og vælge location ud fra en waiting strategy


        # Determine SAE
        averageSAE = 0.0
        for i in 1:10
            expectedRequests, expectedRequestIds  = generateExpectedRequests(N,nFixedRequests,parametersFile)
            allRequests = vcat(fixedRequests, expectedRequests)
            time, distance = updateTimeAndDistanceMatrices(time,distance,allRequests)
            solution, requestBank = regretInsertion(scenario,allRequests) # This should be a different kind of construction. We have fixed requests and the rest should be inserted, but how? Here we could modify the simple construction quite simple to insert. and then potentially use ALNS, could also be a case to see if that improves any thing 
            averageSAE += solution.totalCost
        end
        averageSAE /= 10

        if averageSAE < bestAverageSAE 
            bestAverageSAE = averageSAE
            bestSolution = copySolution(solution)
        end
        
    end

    return bestSolution

end
==#  

@testset "Anticipation Test" begin 
    requestFile = "Data/Konsentra/TransformedData_Data.csv"
    vehiclesFile = "tests/resources/Vehicles.csv"
    parametersFile = "tests/resources/Parameters.csv"
    alnsParameters = "tests/resources/ALNSParameters_Article.json"
    scenarioName = "Konsentra_Data"

    # Make scenario
    nExpected = 10
    scenario, nFixed = readInstanceAnticipation(requestFile, nExpected, vehiclesFile, parametersFile,scenarioName)

    # Choose destroy methods
    destroyMethods = Vector{GenericMethod}()
    addMethod!(destroyMethods,"randomDestroy",randomDestroy!)
    addMethod!(destroyMethods,"worstRemoval",worstRemoval!)
    addMethod!(destroyMethods,"shawRemoval",shawRemoval!)

    #Choose repair methods
    repairMethods = Vector{GenericMethod}()
    addMethod!(repairMethods,"greedyInsertion",greedyInsertion)
    addMethod!(repairMethods,"regretInsertion",regretInsertion)

    initialSolution, requestBank = simpleConstruction(scenario,scenario.offlineRequests)
    solution, requestBank,_,_, _,_,_ = runALNS(scenario, scenario.offlineRequests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution=initialSolution,requestBank=requestBank)

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""


    time = scenario.time
    distance = scenario.distance
    serviceTimes = scenario.serviceTimes
    requests = scenario.requests
    nExpected = N

    removeExpectedRequestsFromSolution!(time,distance,serviceTimes,requests,solution,nExpected,nFixed)
    #printSolution(solution,printRouteHorizontal)

    state = State(solution,Request(),0)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    @test feasible == true
    @test msg == ""
    

end