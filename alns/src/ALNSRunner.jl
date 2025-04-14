module ALNSRunner

using UnPack,JSON, domain, Dates, ..ALNSDomain, ..ALNSFunctions, ..ALNSAlgorithm, ..ALNSResults

export runALNS

#==
 Module to run ALNS algorithm 
==#

function runALNS(scenario::Scenario, requests::Vector{Request}, destroyMethods::Vector{GenericMethod},repairMethods::Vector{GenericMethod};outPutFileFolder="tests/output"::String,parametersFile=""::String,savePlots=true::Bool,displayPlots=true::Bool,plotFolder=""::String,initialSolution=Solution(scenario)::Solution, requestBank=Vector{Int64}(),event = Request(), alreadyRejected = 0::Int, visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}(),stage="Offline")
    # Create time stamp and output file folder
    timeStamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS.sss")
    outputFileFolderWithDate = string(outPutFileFolder,"/",timeStamp,"/")
    
    # Check if the output directory exists, and if not, create it
    if !isdir(outputFileFolderWithDate)
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

    # Create specifications file 
    specificationsFileName = string(outputFileFolderWithDate,"ALNSSpecifications.json")
    writeALNSSpecificationsFile(specificationsFileName,scenario,parameters,configuration)
 
    # Create log file name
    ALNSOutputFileName = string(outputFileFolderWithDate,"ALNSOutput.csv")

    # Call ALNS 
    solution, requestBank = ALNS(scenario,initialSolution, requestBank,configuration,parameters, ALNSOutputFileName, alreadyRejected = alreadyRejected,event = event, visitedRoute=visitedRoute, stage=stage)

    # Write KPIs to file 
    KPIFileName = string(outputFileFolderWithDate,"ALNSKPIs.json")
    writeKPIsToFile(KPIFileName,scenario,solution)

    # Create results 
    if savePlots
        plotFolder = outputFileFolderWithDate
    end

    specification, KPIS = ALNSResult(specificationsFileName,KPIFileName,ALNSOutputFileName,scenario,solution,requests,requestBank,savePlots=savePlots,displayPlots=displayPlots,plotFolder=plotFolder)

    return solution, requestBank, specification, KPIS
end

#==
    Write ALNS specifications to file 
==#
function writeALNSSpecificationsFile(fileName::String, scenario::Scenario,parameters::ALNSParameters,configuration::ALNSConfiguration)
    # Create a dictionary for the entire specifications
    specificationsDict = Dict(
        "Scenario" => Dict("name" => scenario.name),
        "RepairMethods" => [m.name for m in configuration.repairMethods],
        "DestroyMethods" => [m.name for m in configuration.destroyMethods],
        "Parameters" => ALNSParametersToDict(parameters)
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(specificationsDict))
    close(file)
end

#==
 Write KPIs to file  
==#
function writeKPIsToFile(fileName::String, scenario::Scenario,solution::Solution)
    KPIDict = Dict(
        "Scenario" => Dict("name" => scenario.name),
        "TotalCost" => solution.totalCost,
        "TotalDistance" => solution.totalDistance,
        "TotalRideTime" => solution.totalRideTime,
        "TotalIdleTime" => solution.totalIdleTime,
        "nTaxi" => solution.nTaxi
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(KPIDict))
    close(file)
end 

end