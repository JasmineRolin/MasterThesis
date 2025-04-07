module ALNSAlgorithm 

using UnPack, domain, utils, ..ALNSDomain, ..ALNSFunctions

export ALNS

#==
 Module that contains the ALNS algorithm
==#

#==
 Method to run ALNS algorithm
==#
function ALNS(scenario::Scenario, requests::Vector{Request},initialSolution::Solution, requestBank::Vector{Int},configuration::ALNSConfiguration, parameters::ALNSParameters,fileName::String;alreadyRejected = 0,event = Request(),visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}()) 
    # File 
    outputFile = open(fileName, "w")
    nDestroy = length(configuration.destroyMethods)
    nRepair = length(configuration.repairMethods)
    write(outputFile,"Iteration,TotalCost,IsAccepted,IsImproved,IsNewBest,Temperature,DM,RM,",join(["DW$i" for i in 1:nDestroy], ","),",", join(["RW$i" for i in 1:nRepair], ","), "\n")


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
        destroyIdx = destroy!(scenario,trialState,parameters,configuration,visitedRoute = visitedRoute)
        state = State(trialState.currentSolution,event,visitedRoute,alreadyRejected)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        if !feasible
            println("ALNS: AFTER DESTROY INFEASIBLE SOLUTION IN ITERATION:", iteration)
            println(configuration.destroyMethods[destroyIdx].name)
            println(msg) 
             # Close file    
            close(outputFile)
            return currentState.currentSolution, currentState.requestBank
        end

        
    
        # Repair trial solution 
        repairIdx = repair!(scenario,trialState,configuration,visitedRoute=visitedRoute)
        state = State(trialState.currentSolution,event,visitedRoute,alreadyRejected)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        if !feasible
            println("ALNS: AFTER REPAIR INFEASIBLE SOLUTION IN ITERATION:", iteration)
            println(configuration.repairMethods[repairIdx].name)
            println(msg) 
             # Close file    
            close(outputFile)
            return currentState.currentSolution, currentState.requestBank
        end

        # Check if solution is improved
        # TODO: create hash table to check if solution has been visited before
        if trialState.currentSolution.totalCost < currentState.currentSolution.totalCost
            isImproved = true
            isAccepted = true
            currentState.currentSolution = deepcopy(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = trialState.nAssignedRequests


            # Check if new best solution
            if trialState.currentSolution.totalCost < currentState.bestSolution.totalCost
                isNewBest = true
                currentState.bestSolution = deepcopy(trialState.currentSolution)

            end
        # Check if solution is accepted
        elseif accept(temperature,trialState.currentSolution.totalCost - currentState.currentSolution.totalCost)
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
        state = State(currentState.currentSolution,event,visitedRoute,alreadyRejected)
        feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
        if !feasible
            println("ALNS: INFEASIBLE SOLUTION IN ITERATION:", iteration)
            #throw(msg) 
             # Close file    
            close(outputFile)
            return currentState.currentSolution, currentState.requestBank
        end

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


        # Print 
        if iteration % printSegmentSize == 0
            println("==> ALNS: Iteration: ", iteration, ", Current cost: ", currentState.currentSolution.totalCost, ", Best cost: ", currentState.bestSolution.totalCost,", Improvement from initial: ", 100*(initialCost-currentState.bestSolution.totalCost)/initialCost, "%, Temperature: ", temperature)
        end

        # Update iteration
        iteration += 1

    end

    # Close file    
    close(outputFile)

    # Check final solution
    state = State(currentState.currentSolution,event,visitedRoute,alreadyRejected)
    feasible, msg = checkSolutionFeasibilityOnline(scenario,state)
    if !feasible
        println("ALNS: INFEASIBLE FINAL SOLUTION")
        throw(msg) 
    end

    return currentState.bestSolution, currentState.requestBank
end 

end