using offlinesolution
using domain
using utils


function generateExpectedRequests(N::Int,nFixedRequests::Int,parametersFile::String)
    
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

    # Load needed data
    parametersDf = CSV.read(parametersFile, DataFrame)
    bufferTime = parametersDf[1,"buffer_time"]
    maximumRideTimePercent = parametersDf[1,"maximum_ride_time_percent"]
    minimumMaximumRideTime = parametersDf[1,"minimum_maximum_ride_time"]
    probabilities_pickUpTime,probabilities_dropOffTime,_,_,probabilities_location,_,x_range,y_range,probabilities_distance,_,distance_range,_,_,_,_,_= load_simulation_data("Data/Simulation data/")

    # Generate requests
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

    expectedRequests = readRequests(requestDf,N,bufferTime,maximumRideTimePercent, minimumMaximumRideTime,time,extraN = nFixedRequests)

    return expectedRequests, expectedRequestIds

end


function offlineSolutionWithAnticipation(fixedRequests::Vector{Request},N::Int,scenario::Scenario,parameterFile::String)

    bestAverageSAE = maximumFloat64
    bestSolution = Solution()

    for n in 1:10
        # Get values
        serviceTimes = scenario.serviceTimes
        distance = scenario.distance
        time = scenario.time
        requests = scenario.requests

        # Generate expected requests
        expectedRequests, expectedRequestIds  = generateExpectedRequests(N,nFixedRequests,parametersFile) 

        #==
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
            expectedRequests, expectedRequestIds  = generateExpectedRequests(N)
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
        ==#
    end

    return bestSolution

end

