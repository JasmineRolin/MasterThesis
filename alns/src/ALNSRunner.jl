module ALNSRunner

using UnPack, domain, Dates, offlinesolution, ..ALNSDomain, ..ALNSFunctions, ..ALNSAlgorithm

export runALNS

#==
 Module to run ALNS algorithm 
==#

function runALNS(scenario::Scenario, requests::Vector{Request}, destroyMethods::Vector{GenericMethod},repairMethods::Vector{GenericMethod},initialSolutionConstructor=simpleConstruction::Function,outPutFileFolder="tests/resources"::String,parametersFile=""::String)

    # Create log file 
    fileName = string(outPutFileFolder,"ALNSOutput_",string(Dates.now()),".txt")

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
    initialSolution, requestBank = initialSolutionConstructor(scenario)

    # Call ALNS 
    solution = ALNS(scenario,initialSolution, requestBank,configuration,parameters, fileName)

    return solution
end


end