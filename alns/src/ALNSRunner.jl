module ALNSRunner

using UnPack,JSON, domain, Dates, ..ALNSDomain, ..ALNSFunctions, ..ALNSAlgorithm, ..ALNSResults

export runALNS

#==
 Module to run ALNS algorithm 
==#

function runALNS(scenario::Scenario, requests::Vector{Request}, destroyMethods::Vector{GenericMethod},repairMethods::Vector{GenericMethod};outPutFileFolder="tests/output"::String,parametersFile=""::String,saveResults=false::Bool,displayPlots=false::Bool,initialSolution=Solution(scenario)::Solution, requestBank=Vector{Request}(),event = Request(), alreadyRejected = 0::Int, visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}(),stage="Offline")
    # Create time stamp and output file folder
    timeStamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")
    outputFileFolderWithDate = string(outPutFileFolder,"/",timeStamp,"/")
    
    # Check if the output directory exists, and if not, create it
    if saveResults && !isdir(outputFileFolderWithDate)
        mkdir(outputFileFolderWithDate)
    end

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

    # Create log file name
    ALNSOutputFileName = string(outputFileFolderWithDate,"ALNSOutput.csv")

    # Call ALNS 
    solution, requestBank,pVals,deltaVals,isImprovedVec,isAcceptedVec,isNewBestVec = ALNS(scenario,initialSolution, requestBank,configuration,parameters, ALNSOutputFileName, alreadyRejected = alreadyRejected,event = event, visitedRoute=visitedRoute, saveOutPut = saveResults,stage=stage)

    # Create results 
    specificationsFileName = string(outputFileFolderWithDate,"ALNSSpecifications.json")
    KPIFileName = string(outputFileFolderWithDate,"ALNSKPIs.json")
    plotFolder = outputFileFolderWithDate

    ALNSResult(specificationsFileName,KPIFileName,ALNSOutputFileName,scenario,configuration,solution,requests,requestBank,parameters,saveResults=saveResults,displayPlots=displayPlots,plotFolder=plotFolder)

    return solution, requestBank,pVals,deltaVals, isImprovedVec,isAcceptedVec,isNewBestVec # TODO: remove
end


end