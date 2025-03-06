module ALNSRunner

using UnPack, domain, offlinesolution, ..ALNSDomain, ..ALNSFunctions, ..ALNSAlgorithm

export runALNS

#==
 Module to run ALNS algorithm 
==#

function runALNS(scenario::Scenario, requests::Vector{Request}, destroyMethods::Vector{GenericMethod},repairMethods::Vector{GenericMethod},initialSolutionConstructor=simpleConstruction::Function,parametersFile=""::String)

    # Retrieve relevant activity ids from requests 
    activityIdx = Int[]
    for request in requests
        push!(activityIdx,request.pickUpActivity.id)
        push!(activityIdx,request.dropOffActivity.id)
    end

    # Vehicle indexes 
    vehicleIdx = collect(length(scenario.requests)+1:length(scenario.requests)+scenario.nDepots)
    allIdx = [activityIdx;vehicleIdx]

    # Read parameters 
    if parametersFile == ""
        parameters = ALNSParameters()
    else
        parameters = readALNSParameters(parametersFile)
    end
    setMinMaxValuesALNSParameters(parameters,scenario.time[allIdx,allIdx],requests)

    # Create ALNS configuration 
    configuration = ALNSConfiguration(parameters,destroyMethods,repairMethods)

    # Construct initial solution 
    initialSolution = initialSolutionConstructor(scenario)

    # Call ALNS 
    solution = ALNS(scenario,initialSolution,configuration,parameters)

    return solution
end


end