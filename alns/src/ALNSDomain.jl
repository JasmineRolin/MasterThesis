module ALNSDomain 

using LinearAlgebra, domain 

export GenericMethod
export ALNSParameters
export ALNSConfiguration
export ALNSState
export setMinMaxValuesALNSParameters, ALNSParametersToDict,copyALNSState

#==
 Struct to describe destroy or repair method 
==#
mutable struct GenericMethod
    name::String 
    method::Function
end


#==
 Struct that contains ALNS parameters 
==#
mutable struct ALNSParameters
    timeLimit::Float64 
    printSegmentSize::Int # Number of iterations before printing 
    segmentSize::Int # Number of iterations in a segment
    reactionFactor::Float64 # How quickly to react to new score -  new_weight = old_weight*(1-reactionFactor) + score *reactionFactor;
    scoreAccepted::Float64 # Score given for an accepted solution
	scoreImproved::Float64 # Score given for a solution that is better than the current solution
	scoreNewBest::Float64 # Score given for a new global best solution
    minPercentToDestroy::Float64 # Minimum percentage of requests to destroy
    maxPercentToDestroy::Float64 # Maximum percentage of requests to destroy
    p::Float64 # weight to adjust probability of removing worst request. Low value of p corresponds to much randomness
    shawRemovalPhi::Float64 # weight for drive time relatedness 
    shawRemovalXi::Float64 # weight for time window relatedness
    maxDriveTime::Float64 # Minimum drive time in scenario 
    minDriveTime::Float64 # Maximum drive time in scenario 
    minStartOfTimeWindowPickUp::Float64 # Minimum start of time window for pick-up in scenario
    maxStartOfTimeWindowPickUp::Float64 # Maximum start of time window for pick-up in scenario
    minStartOfTimeWindowDropOff::Float64 # Minimum start of time window for drop-off in scenario
    maxStartOfTimeWindowDropOff::Float64 # Maximum start of time window for drop-off in scenario
    maxNumberOfIterationsWithoutImprovement::Int # Number of iterations without improvement before stopping
    maxNumberOfIterationsWithoutNewBest::Int # Number of iterations without new best before stopping

    function ALNSParameters( 
        timeLimit=10.0, 
        printSegmentSize=100,
        segmentSize=100, # TODO: not from paper 
        reactionFactor=0.01, 
        scoreAccepted=2.0, 
        scoreImproved=4.0, 
        scoreNewBest=10.0,
        minPercentToDestroy=0.1,
        maxPercentToDestroy=0.3,
        p=6.0,
        shawRemovalPhi=9.0,
        shawRemovalXi=3.0,
        maxNumberOfIterationsWithoutImprovement=1000,
        maxNumberOfIterationsWithoutNewBest=5000
        )
        return new(timeLimit,printSegmentSize,segmentSize,reactionFactor, scoreAccepted, scoreImproved, scoreNewBest,minPercentToDestroy,maxPercentToDestroy,p,shawRemovalPhi,shawRemovalXi,0.0,0.0,0.0,0.0,0.0,0.0,maxNumberOfIterationsWithoutImprovement,maxNumberOfIterationsWithoutNewBest)
    end
end

function setMinMaxValuesALNSParameters(parameters::ALNSParameters,time,requests)
    parameters.maxDriveTime = Float64(maximum(time))
    parameters.minDriveTime = Float64(minimum(time + I*typemax(Int)))
    parameters.maxStartOfTimeWindowPickUp = Float64(maximum([request.pickUpActivity.timeWindow.startTime for request in requests]))
    parameters.minStartOfTimeWindowPickUp = Float64(minimum([request.pickUpActivity.timeWindow.startTime for request in requests]))
    parameters.maxStartOfTimeWindowDropOff = Float64(maximum([request.dropOffActivity.timeWindow.startTime for request in requests]))
    parameters.minStartOfTimeWindowDropOff = Float64(minimum([request.dropOffActivity.timeWindow.startTime for request in requests]))
end

function ALNSParametersToDict(params::ALNSParameters)
    return Dict(
        "timeLimit" => params.timeLimit,
        "printSegmentSize" => params.printSegmentSize,
        "segmentSize" => params.segmentSize,
        "reactionFactor" => params.reactionFactor,
        "scoreAccepted" => params.scoreAccepted,
        "scoreImproved" => params.scoreImproved,
        "scoreNewBest" => params.scoreNewBest,
        "minPercentToDestroy" => params.minPercentToDestroy,
        "maxPercentToDestroy" => params.maxPercentToDestroy,
        "p" => params.p,
        "shawRemovalPhi" => params.shawRemovalPhi,
        "shawRemovalXi" => params.shawRemovalXi,
        "maxDriveTime" => params.maxDriveTime,
        "minDriveTime" => params.minDriveTime,
        "minStartOfTimeWindowPickUp" => params.minStartOfTimeWindowPickUp,
        "maxStartOfTimeWindowPickUp" => params.maxStartOfTimeWindowPickUp,
        "minStartOfTimeWindowDropOff" => params.minStartOfTimeWindowDropOff,
        "maxStartOfTimeWindowDropOff" => params.maxStartOfTimeWindowDropOff,
        "maxNumberOfIterationsWithoutImprovement" => params.maxNumberOfIterationsWithoutImprovement,
        "maxNumberOfIterationsWithoutNewBest" => params.maxNumberOfIterationsWithoutNewBest
    )
end


#==
 Struct to describe configuration of ALNS algorithm 
==#
mutable struct ALNSConfiguration
    destroyMethods::Vector{GenericMethod}
    repairMethods::Vector{GenericMethod}
    parameters::ALNSParameters

    function ALNSConfiguration(parameters::ALNSParameters)
        return new(Vector{GenericMethod}(), Vector{GenericMethod}(),parameters)
    end

    function ALNSConfiguration(parameters::ALNSParameters, destroyMethods::Vector{GenericMethod},repairMethods::Vector{GenericMethod})
        return new(destroyMethods, repairMethods, parameters)
    end
end

#==
 Struct to describe current state of ALNS algorithm 
==#
mutable struct ALNSState 
    destroyWeights::Vector{Float64}
    repairWeights::Vector{Float64}
    destroyScores::Vector{Float64}
    repairScores::Vector{Float64}
    destroyNumberOfUses::Vector{Int} # Number of times method has been used in current segment 
    repairNumberOfUses::Vector{Int} # Number of times method has been used in current segment 
    bestSolution::Solution
    bestRequestBank::Vector{Int} 
    currentSolution::Solution
    requestBank::Vector{Int}
    assignedRequests::Vector{Int}
    nAssignedRequests::Int
    seenSolutions::Vector{String}

    function ALNSState(currentSolution::Solution,nDestroy::Int,nRepair::Int)
        assignedRequestsSet = Vector{Int}()
        for schedule in currentSolution.vehicleSchedules
            for activityAssignment in schedule.route
                if activityAssignment.activity.activityType == PICKUP
                    push!(assignedRequestsSet,activityAssignment.activity.requestId)
                end
            end
        end

        assignedRequests = collect(assignedRequestsSet)

        return new(ones(nDestroy)./nDestroy,ones(nRepair)./nRepair,zeros(nDestroy),zeros(nRepair),zeros(Int,nDestroy),zeros(Int,nRepair),copySolution(currentSolution),Vector{Int}(),currentSolution,Vector{Int}(),assignedRequests,length(assignedRequests),fill("", 100))
    end

    function ALNSState(currentSolution::Solution,nDestroy::Int,nRepair::Int,requestBank::Vector{Int})
        assignedRequestsSet = Vector{Int}()
        for schedule in currentSolution.vehicleSchedules
            for activityAssignment in schedule.route
                if activityAssignment.activity.activityType == PICKUP
                    push!(assignedRequestsSet,activityAssignment.activity.requestId)
                end
            end
        end

        assignedRequests = collect(assignedRequestsSet)

        return new(ones(nDestroy)./nDestroy,ones(nRepair)./nRepair,zeros(nDestroy),zeros(nRepair),zeros(Int,nDestroy),zeros(Int,nRepair),copySolution(currentSolution),deepcopy(requestBank),currentSolution,requestBank,assignedRequests,length(assignedRequests),fill("", 100))
    end

    # All-argument constructor
    function ALNSState(
        destroyWeights::Vector{Float64}, 
        repairWeights::Vector{Float64}, 
        destroyScores::Vector{Float64},
        repairScores::Vector{Float64},
        destroyNumberOfUses::Vector{Int}, 
        repairNumberOfUses::Vector{Int}, 
        bestSolution::Solution, 
        bestRequestBank::Vector{Int},
        currentSolution::Solution, 
        requestBank::Vector{Int}, 
        assignedRequests::Vector{Int},
        nAssignedRequests::Int
    )
        return new(destroyWeights, repairWeights,destroyScores,repairScores, destroyNumberOfUses, repairNumberOfUses, bestSolution,bestRequestBank, currentSolution, requestBank, assignedRequests, nAssignedRequests,fill("", 100))
    end


end

#==
 Method to copy ALNS state
==#
function copyALNSState(alnsState::ALNSState)
    return ALNSState(
        deepcopy(alnsState.destroyWeights),
        deepcopy(alnsState.repairWeights),
        deepcopy(alnsState.destroyScores),
        deepcopy(alnsState.repairScores),
        deepcopy(alnsState.destroyNumberOfUses),
        deepcopy(alnsState.repairNumberOfUses),
        copySolution(alnsState.bestSolution),
        deepcopy(alnsState.bestRequestBank),
        copySolution(alnsState.currentSolution),
        deepcopy(alnsState.requestBank),
        deepcopy(alnsState.assignedRequests),
        alnsState.nAssignedRequests
    )
end


end