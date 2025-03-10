module ALNSAlgorithm 

using UnPack, domain, utils, ..ALNSDomain, ..ALNSFunctions

export ALNS

#==
 Module that contains the ALNS algorithm
==#

#==
 Method to run ALNS algorithm
==#
function ALNS(scenario::Scenario,initialSolution::Solution, requestBank::Vector{Int},configuration::ALNSConfiguration, parameters::ALNSParameters)::Solution 
    
    println("Initial solution cost", initialSolution.totalCost)

    # Unpack parameters
    @unpack timeLimit, w, coolingRate, segmentSize, reactionFactor, scoreAccepted, scoreImproved, scoreNewBest  = parameters

    # Create ALNS state
    currentState = ALNSState(initialSolution, length(configuration.destroyMethods), length(configuration.repairMethods), requestBank)

    # Initialize temperature, iteration and time 
    temperature = findStartTemperature(w,currentState.currentSolution)
    println("Starting temperature: ", temperature)

    iteration = 0
    startTime = time()

    # Iterate while time limit is not reached 
    while !termination(startTime,timeLimit)
        println("--> ALNS iteration: ", iteration)
        isAccepted = false 
        isImproved = false
        isNewBest = false

        # Create copy of current state
        trialState = deepcopy(currentState)

        # Destroy trial solution  
        destroyIdx = destroy!(scenario,trialState,parameters,configuration)

        # Repair trial solution 
        repairIdx = repair!(scenario,trialState,configuration)

        # Check if solution is improved
        # TODO: create hash table to check if solution has been visited before
        # TODO: jas - update . accept always true if solution is better than current sol!
        if trialState.currentSolution.totalCost < currentState.currentSolution.totalCost
            println("\t New improved solution: ", trialState.currentSolution.totalCost, " old cost: ", currentState.currentSolution.totalCost)

            isImproved = true
            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = deepcopy(trialState.nAssignedRequests)

            # Check if new best solution
            if trialState.currentSolution.totalCost < currentState.bestSolution.totalCost
                println("\t New best solution: ", trialState.currentSolution.totalCost, " old cost: ", currentState.currentSolution.totalCost)

                isNewBest = true
                currentState.bestSolution = deepcopy(trialState.currentSolution)
            end
        # Check if solution is accepted
        elseif accept(temperature,trialState.currentSolution.totalCost - currentState.currentSolution.totalCost)
            println("\t Solution accepted: new cost", trialState.currentSolution.totalCost, " old cost: ", currentState.currentSolution.totalCost)

            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = deepcopy(trialState.nAssignedRequests)

        end

        # Update method scores and counts 
        updateScoreAndCount(scoreAccepted,scoreImproved,scoreNewBest,currentState,destroyIdx,repairIdx,isAccepted,isImproved,isNewBest)

        # Update weights and reset scores and count if end of segment
        updateWeightsAfterEndOfSegment(segmentSize,currentState,reactionFactor,iteration)

        # Update temperature and iteration
        temperature = coolingRate*temperature
        println("\t Temperature: ", temperature)

        # Check solution 
        # TODO: remove when ALNS is robust 
        feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution)
        if !feasible
            throw(msg) 
        else
            println("Feasible solution")
        end

        # Update iteration
        iteration += 1

    end

    return currentState.bestSolution
end 

end