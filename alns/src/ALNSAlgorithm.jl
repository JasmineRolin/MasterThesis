module ALNSAlgorithm 

using UnPack, domain, ..ALNSDomain, ..ALNSFunctions

export ALNS

#==
 Module that contains the ALNS algorithm
==#

#==
 Method to run ALNS algorithm
==#
function ALNS(scenario::Scenario,initialSolution::Solution,configuration::ALNSConfiguration, parameters::ALNSParameters)::Solution 
    # TODO: implement ALNS     

    # Unpack parameters
    @unpack timeLimit, w, coolingRate, segmentSize, reactionFactor, scoreAccepted, scoreImproved, scoreNewBest  = parameters

    # Create ALNS state
    currentState = ALNSState(initialSolution, length(configuration.destroyMethods), length(configuration.repairMethods))

    # Initialize temperature, iteration and time 
    temperature = findStartTemperature(w,currentState.currentSolution)
    iteration = 0
    startTime = time()

    # Iterate while time limit is not reached 
    while !terminate(startTime,timeLimit)
        isAccepted = false 
        isImproved = false
        isNewBest = false

        # Create copy of current state
        trialState = deepcopy(currentState)

        # Destroy trial solution  
        destroyIdx = destroy!(scenario,trialState,parameters,configuration)

        # Repair trial solution 
        repairIdx = repair!(configuration,parameters,trialState,trialState.currentSolution)

        # Check if solution is improved
        # TODO: create hash table to check if solution has been visited before
        if trialState.currentSolution.totalCost < currentState.currentSolution.totalCost
            isImproved = true
            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)

            # Check if new best solution
            if trialState.currentSolution.totalCost < currentState.bestSolution.totalCost
                isNewBest = true
                currentState.bestSolution = deepcopy(trialState.currentSolution)
            end
        # Check if solution is accepted
        elseif accept(temperature,trialState.currentSolution.totalCost - currentState.currentSolution.totalCost)
            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)
        end

        # Update method scores and counts 
        updateScoreAndCount(scoreAccepted,scoreImproved,scoreNewBest,currentState,destroyIdx,repairIdx,isAccepted,isImproved,isNewBest)

        # Update weights and reset scores and count if end of segment
        updateAfterEndOfSegment(segmentSize,currentState,reactionFactor,iteration)

        # Update temperature and iteration
        temperature = coolingRate*temperature
    end
end 

end