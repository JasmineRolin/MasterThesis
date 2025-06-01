module ALNSAlgorithm

using UnPack, domain, utils, ..ALNSDomain, ..ALNSFunctions
using TimerOutputs

export ALNS

#==
 Module that contains the ALNS algorithm
==#

global epsilon = 0.0001
const TO = TimerOutput()

#==
 Method to run ALNS algorithm
==#
function ALNS(scenario::Scenario, initialSolution::Solution, requestBank::Vector{Int},configuration::ALNSConfiguration, parameters::ALNSParameters, fileName::String;alreadyRejected=0, event=Request(), visitedRoute::Dict{Int,Dict{String,Int}}=Dict(),saveOutPut=false, stage="Offline", nNotServicedExpectedRequests::Int=0)
    eventId = event.id
    nDestroy = length(configuration.destroyMethods)
    nRepair = length(configuration.repairMethods)

    if saveOutPut
        outputFile = open(fileName, "w")
        write(outputFile, "Iteration,TotalCost,nRequestBank,IsAccepted,IsImproved,IsNewBest,DM,RM," *
                          join(["DW$i" for i in 1:nDestroy], ",") * "," *
                          join(["RW$i" for i in 1:nRepair], ",") *
                          join(["nD$i" for i in 1:nDestroy], ",") * "," *
                          join(["nR$i" for i in 1:nRepair], ",") * "\n")
    end

    @unpack timeLimit, segmentSize, reactionFactor,
    scoreAccepted, scoreImproved, scoreNewBest,
    printSegmentSize, maxNumberOfIterationsWithoutImprovement,
    maxNumberOfIterationsWithoutNewBest = parameters

    currentState = ALNSState(initialSolution, nDestroy, nRepair, requestBank)
    initialCost = initialSolution.totalCost

    iteration = 0
    newSolutions = 0
    numberOfIterationsSinceLastImprovement = 0
    numberOfIterationsSinceLastBest = 0
    startTime = time()

    pVals, deltaVals = [], []
    countAccepted = 0
    isImprovedVec, isNewBestVec, isAcceptedVec = [], [], []

    reset_timer!(TO)  # Reset timer for this ALNS run

    while !(termination(startTime, timeLimit) || numberOfIterationsSinceLastImprovement > maxNumberOfIterationsWithoutImprovement || numberOfIterationsSinceLastBest > maxNumberOfIterationsWithoutNewBest)
        isAccepted, isImproved, isNewBest = false, false, false

        trialState = copyALNSState(currentState)

        @timeit TO "Destroy!" begin
            destroyIdx = destroy!(scenario, trialState, parameters, configuration, visitedRoute=visitedRoute,TO=TO)
        end
    

        @timeit TO "Repair!" begin
            repairIdx = repair!(scenario, trialState, configuration, visitedRoute=visitedRoute,TO=TO)
        end
      
        @timeit TO "Hash solution" begin 
            hashKeySolution =  hashSolution(trialState.currentSolution)
            seenBefore = hashKeySolution in currentState.seenSolutions
            if !seenBefore
                newSolutions += 1
                popfirst!(currentState.seenSolutions)
                push!(currentState.seenSolutions, hashKeySolution)
            end
        end

        acceptOnlinePhase = if stage == "Online"
            relevantRequestBank = trialState.requestBank[trialState.requestBank .<= scenario.nFixed]
            (length(relevantRequestBank) == 0) || (eventId in relevantRequestBank && length(relevantRequestBank) == 1)
        else
            true
        end

        acceptBool, p, delta = accept(parameters.timeLimit, startTime, trialState.currentSolution.totalCost, currentState.bestSolution.totalCost)
        push!(pVals, p)
        push!(deltaVals, delta)

        if acceptOnlinePhase && !seenBefore && (trialState.currentSolution.totalCost < currentState.currentSolution.totalCost - epsilon)
            isImproved, isAccepted = true, true
            currentState.currentSolution = copySolution(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = trialState.nAssignedRequests

            if  (trialState.currentSolution.totalCost < currentState.bestSolution.totalCost - epsilon)
                isNewBest = true
                currentState.bestSolution = copySolution(trialState.currentSolution)
                currentState.bestRequestBank = deepcopy(trialState.requestBank)
            end
        elseif acceptOnlinePhase && !seenBefore && acceptBool
            countAccepted += 1
            isAccepted = true
            currentState.currentSolution = copySolution(trialState.currentSolution)
            currentState.requestBank = deepcopy(trialState.requestBank)
            currentState.assignedRequests = deepcopy(trialState.assignedRequests)
            currentState.nAssignedRequests = trialState.nAssignedRequests
        end

        @timeit TO "Update Scores" begin
            updateScoreAndCount(scoreAccepted, scoreImproved, scoreNewBest, currentState, destroyIdx, repairIdx, isAccepted, isImproved, isNewBest)
            updateWeightsAfterEndOfSegment(segmentSize, currentState, reactionFactor, iteration)
        end


        if saveOutPut
            write(outputFile, string(iteration), ",",
                string(trialState.currentSolution.totalCost), ",",
                string(length(trialState.requestBank)), ",",
                string(isAccepted), ",",
                string(isImproved), ",",
                string(isNewBest), ",",
                string(configuration.destroyMethods[destroyIdx].name), ",",
                string(configuration.repairMethods[repairIdx].name), ",",
                join(string.(currentState.destroyWeights), ","), ",",
                join(string.(currentState.repairWeights), ","),
                join(string.(currentState.destroyNumberOfUses), ","), ",",
                join(string.(currentState.repairNumberOfUses), ","), "\n")
        end

        # TODO: remove when ALNS is robust 
        @timeit TO "Feasibility Check" begin
            state = State(currentState.currentSolution, event, visitedRoute, alreadyRejected)
            feasible, msg = checkSolutionFeasibilityOnline(scenario, state, nExpected = nNotServicedExpectedRequests)
            if !feasible
                println("ALNS: INFEASIBLE SOLUTION IN ITERATION:", iteration)
                printSolution(currentState.currentSolution, printRouteHorizontal)
                show(TO)
                throw(msg)
            end
        end

        if iteration % printSegmentSize == 0
            println("==> ALNS: Iteration: ", iteration, ", Current cost: ", currentState.currentSolution.totalCost," current request bank: ",currentState.currentSolution.nTaxi, ", Best cost: ", currentState.bestSolution.totalCost," best request bank: ",currentState.bestSolution.nTaxi," best exp request bank: ",currentState.bestSolution.nTaxiExpected,", Improvement from initial: ", 100*(initialCost-currentState.bestSolution.totalCost)/initialCost, ", New solutions: ",newSolutions, " /", iteration)
        end

        iteration += 1

        if isNewBest
            numberOfIterationsSinceLastBest = 0
            numberOfIterationsSinceLastImprovement = 0
        elseif isImproved
            numberOfIterationsSinceLastImprovement = 0
            numberOfIterationsSinceLastBest += 1
        else
            numberOfIterationsSinceLastImprovement += 1
            numberOfIterationsSinceLastBest += 1
        end

        push!(isImprovedVec, isImproved)
        push!(isNewBestVec, isNewBest)
        push!(isAcceptedVec, isAccepted)
    end

    if saveOutPut
        close(outputFile)
    end

    state = State(currentState.bestSolution, event, visitedRoute, alreadyRejected)
    feasible, msg = checkSolutionFeasibilityOnline(scenario, state, nExpected = nNotServicedExpectedRequests)
    if !feasible
        println("ALNS: INFEASIBLE FINAL SOLUTION")
        throw(msg)
    end

    # TODO: remove 
    println("Total number of iterations: ", iteration)
    println("Termination: max since last improvement: ", numberOfIterationsSinceLastImprovement > maxNumberOfIterationsWithoutImprovement,
        ", max since last best: ", numberOfIterationsSinceLastBest > maxNumberOfIterationsWithoutNewBest)
    # println("\n Timing Breakdown:")
    
    # show(TO)

    return currentState.bestSolution, currentState.bestRequestBank, pVals, deltaVals, isImprovedVec, isAcceptedVec, isNewBestVec, iteration
end

end