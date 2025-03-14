module ALNSAlgorithm 

using UnPack, domain, utils, ..ALNSDomain, ..ALNSFunctions

export ALNS

#==
 Module that contains the ALNS algorithm
==#

#==
 Method to run ALNS algorithm
==#
function ALNS(scenario::Scenario, requests::Vector{Request},initialSolution::Solution, requestBank::Vector{Int},configuration::ALNSConfiguration, parameters::ALNSParameters,fileName::String) 
    
    # File 
    outputFile = open(fileName, "w")
    nDestroy = length(configuration.destroyMethods)
    nRepair = length(configuration.repairMethods)
    write(outputFile,"Iteration,TotalCost,IsAccepted,IsImproved,IsNewBest,Temperature,",join(["DW$i" for i in 1:nDestroy], ","),",", join(["RW$i" for i in 1:nRepair], ","), "\n")


    # Unpack parameters
    @unpack timeLimit, w, coolingRate, segmentSize, reactionFactor, scoreAccepted, scoreImproved, scoreNewBest, printSegmentSize  = parameters

    # Create ALNS state
    currentState = ALNSState(initialSolution, length(configuration.destroyMethods), length(configuration.repairMethods), requestBank)
    initialCost = initialSolution.totalCost

    # Initialize temperature, iteration and time 
    temperature = findStartTemperature(w,currentState.currentSolution,scenario.taxiParameter)

    iteration = 0
    startTime = time()

    # Iterate while time limit is not reached 
    while !termination(startTime,timeLimit)
        isAccepted = false 
        isImproved = false
        isNewBest = false

        # Create copy of current state
        trialState = deepcopy(currentState)

        # Destroy trial solution  
        destroyIdx = destroy!(scenario,trialState,parameters,configuration)

        feasible, msg = checkSolutionFeasibility(scenario,trialState.currentSolution,requests)
        if !feasible
            println("ALNS: INFEASIBLE SOLUTION AFTER Destroy IN ITERATION:", iteration)
            throw(msg) 
        end

        # Repair trial solution 
        repairIdx = repair!(scenario,trialState,configuration)

        feasible, msg = checkSolutionFeasibility(scenario,trialState.currentSolution,requests)
        if !feasible
            println("ALNS: INFEASIBLE SOLUTION AFTER Repair IN ITERATION:", iteration)
            throw(msg) 
        end

        # Check if solution is improved
        # TODO: create hash table to check if solution has been visited before
        # TODO: jas - update . accept always true if solution is better than current sol!
        if trialState.currentSolution.totalCost < currentState.currentSolution.totalCost
           # println("==>ALNS: IMPROVED: Iteration: ", iteration, ", Current cost: ", currentState.currentSolution.totalCost,", Trial cost: ", trialState.currentSolution.totalCost)

            isImproved = true
            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = trialState.nAssignedRequests


            # Check if new best solution
            if trialState.currentSolution.totalCost < currentState.bestSolution.totalCost
               # println("==>ALNS: NEW BEST: Iteration: ", iteration, ", Best cost: ", trialState.currentSolution.totalCost,", Previous best: ", currentState.bestSolution.totalCost)

                isNewBest = true
                currentState.bestSolution = deepcopy(trialState.currentSolution)

            end
        # Check if solution is accepted
        elseif accept(temperature,trialState.currentSolution.totalCost - currentState.currentSolution.totalCost)
           # println("==>ALNS: ACCEPTED: Iteration: ", iteration, ", Current cost: ", currentState.currentSolution.totalCost,", Trial cost: ", trialState.currentSolution.totalCost)

            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)
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

        # Check solution 
        # TODO: remove when ALNS is robust 
        feasible, msg = checkSolutionFeasibility(scenario,currentState.currentSolution,requests)
        if !feasible
            println("ALNS: INFEASIBLE SOLUTION IN ITERATION:", iteration)
            throw(msg) 
        end

        # Write to file 
        write(outputFile, string(iteration), ",", 
                 string(trialState.currentSolution.totalCost), ",", 
                 string(isAccepted), ",", 
                 string(isImproved), ",", 
                 string(isNewBest), ",", 
                 string(temperature), ",", 
                 join(string.(currentState.destroyWeights), ","), ",", 
                 join(string.(currentState.repairWeights), ","), "\n")


        # Print 
        if iteration % printSegmentSize == 0
            println("==> ALNS: Iteration: ", iteration, ", Current cost: ", currentState.currentSolution.totalCost, ", Best cost: ", currentState.bestSolution.totalCost,", Improvement from initial: ", (initialCost-currentState.bestSolution.totalCost)/initialCost, "%, Temperature: ", temperature)
        end

        # Update iteration
        iteration += 1

    end

    # Close file    
    close(outputFile)

    # Check final solution
    feasible, msg = checkSolutionFeasibility(scenario,currentState.bestSolution,requests)
    if !feasible
        println("ALNS: INFEASIBLE FINAL SOLUTION")
        throw(msg) 
    end

    return currentState.bestSolution, currentState.requestBank
end 

end