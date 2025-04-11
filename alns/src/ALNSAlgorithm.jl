module ALNSAlgorithm 

using UnPack, domain, utils, ..ALNSDomain, ..ALNSFunctions

export ALNS

#==
 Module that contains the ALNS algorithm
==#

#==
 Method to run ALNS algorithm
==#
function ALNS(scenario::Scenario,initialSolution::Solution, requestBank::Vector{Int},configuration::ALNSConfiguration, parameters::ALNSParameters,fileName::String;alreadyRejected = 0,event = Request(),visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}()) 
    # Retrieve event id 
    eventId = event.id 

    # File 
    outputFile = open(fileName, "w")
    nDestroy = length(configuration.destroyMethods)
    nRepair = length(configuration.repairMethods)
    write(outputFile,"Iteration,TotalCost,IsAccepted,IsImproved,IsNewBest,Temperature,DM,RM,",join(["DW$i" for i in 1:nDestroy], ","),",", join(["RW$i" for i in 1:nRepair], ","), "\n")


    # Unpack parameters
    @unpack timeLimit, w, coolingRate, segmentSize, reactionFactor, scoreAccepted, scoreImproved, scoreNewBest, printSegmentSize, maxNumberOfIterationsWithoutImprovement = parameters

    # Create ALNS state
    currentState = ALNSState(initialSolution, length(configuration.destroyMethods), length(configuration.repairMethods), requestBank)
    initialCost = initialSolution.totalCost

    # Initialize temperature, iteration and time 
    temperature = findStartTemperature(w,currentState.currentSolution,scenario.taxiParameter)

    iteration = 0
    numberOfIterationsSinceLastImprovement = 0
    startTime = time()

    # Iterate while time limit is not reached 
    while !(termination(startTime,timeLimit) || numberOfIterationsSinceLastImprovement > maxNumberOfIterationsWithoutImprovement)
        isAccepted = false 
        isImproved = false
        isNewBest = false

        # Create copy of current state
        trialState = copyALNSState(currentState)

        # Destroy trial solution  
        destroyIdx = destroy!(scenario,trialState,parameters,configuration,visitedRoute = visitedRoute)
       
        # Repair trial solution 
        repairIdx = repair!(scenario,trialState,configuration,visitedRoute=visitedRoute)
    

        # Check if solution is improved
        hashKeySolution = hashSolution(trialState.currentSolution)
        seenBefore = hashKeySolution in currentState.seenSolutions
        if !seenBefore
            popfirst!(currentState.seenSolutions)
            push!(currentState.seenSolutions, hashKeySolution)
        end


        # Check if we can accept solution when trying to insert event 
        #    Is true when we are in offline phase: eventId == 0 
        #    Is true when we are in online phase and the request bank is empty
        #    Is true when we are in online phase and the event is the only request in the request bank
        acceptOnlinePhase = (eventId == 0) || (length(trialState.requestBank) == 0) || (eventId in trialState.requestBank && length(trialState.requestBank) == 1)

        if acceptOnlinePhase && !seenBefore && (trialState.currentSolution.totalCost < currentState.currentSolution.totalCost)
            isImproved = true
            isAccepted = true
            currentState.currentSolution = copySolution(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = trialState.nAssignedRequests


            # Check if new best solution
            if trialState.currentSolution.totalCost < currentState.bestSolution.totalCost
                isNewBest = true
                currentState.bestSolution = copySolution(trialState.currentSolution)
                currentState.bestRequestBank = deepcopy(trialState.requestBank)

            end
        # Check if solution is accepted
        elseif acceptOnlinePhase && !seenBefore && (accept(temperature,trialState.currentSolution.totalCost - currentState.currentSolution.totalCost))
            isAccepted = true
            currentState.currentSolution = copySolution(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = trialState.nAssignedRequests
        end

        # Update method scores and counts 
        updateScoreAndCount(scoreAccepted,scoreImproved,scoreNewBest,currentState,destroyIdx,repairIdx,isAccepted,isImproved,isNewBest)

        # Update weights and reset scores and count if end of segment
        updateWeightsAfterEndOfSegment(segmentSize,currentState,reactionFactor,iteration)

        # Update temperature and iteration
        temperature = coolingRate*temperature

        # Write to file 
        write(outputFile, string(iteration), ",", 
                 string(trialState.currentSolution.totalCost), ",", 
                 string(isAccepted), ",", 
                 string(isImproved), ",", 
                 string(isNewBest), ",", 
                 string(temperature), ",", 
                string(configuration.destroyMethods[destroyIdx].name), ",",
                string(configuration.repairMethods[repairIdx].name), ",",
                join(string.(currentState.destroyWeights), ","), ",", 
                 join(string.(currentState.repairWeights), ","), "\n")


        # Check solution 
        # TODO: remove when ALNS is robust 
        state = State(currentState.currentSolution,event,visitedRoute,alreadyRejected)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        if !feasible
            println("ALNS: INFEASIBLE SOLUTION IN ITERATION:", iteration)  
            close(outputFile)
            throw(msg) 
        end


        # Print 
        if iteration % printSegmentSize == 0
            println("==> ALNS: Iteration: ", iteration, ", Current cost: ", currentState.currentSolution.totalCost," current request bank: ",currentState.currentSolution.nTaxi, ", Best cost: ", currentState.bestSolution.totalCost," best request bank: ",currentState.bestSolution.nTaxi,", Improvement from initial: ", 100*(initialCost-currentState.bestSolution.totalCost)/initialCost, "%, Temperature: ", temperature)
        end

        # Update iteration
        iteration += 1

        if isImproved
            numberOfIterationsSinceLastImprovement = 0
        else
            numberOfIterationsSinceLastImprovement += 1
        end

    end

    # Close file    
    close(outputFile)

    # Check final solution
    state = State(currentState.bestSolution,event,visitedRoute,alreadyRejected)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println("ALNS: INFEASIBLE FINAL SOLUTION")
        throw(msg) 
    end

    return currentState.bestSolution, currentState.bestRequestBank
end 

end