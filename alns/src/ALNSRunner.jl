module ALNSRunner

using UnPack,JSON, domain, Dates, offlinesolution, ..ALNSDomain, ..ALNSFunctions, ..ALNSAlgorithm

export runALNS

#==
 Module to run ALNS algorithm 
==#

function runALNS(scenario::Scenario, requests::Vector{Request}, destroyMethods::Vector{GenericMethod},repairMethods::Vector{GenericMethod};initialSolutionConstructor=simpleConstruction::Function,outPutFileFolder="tests/output/"::String,parametersFile=""::String)

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
    timeStamp = Dates.format(Dates.now(), "yyyy-mm-dd-HH:MM:sss")
    fileName = string(outPutFileFolder,"ALNSOutput_",string(timeStamp),".csv")

    # Create specifications file 
    specificationsFile = string(outPutFileFolder,"ALNSSpecifications_",string(timeStamp),".json")
    writeALNSSpecificationsFile(specificationsFile,scenario,parameters,configuration)
 

    # Construct initial solution 
    initialSolution, requestBank = initialSolutionConstructor(scenario)

    # Call ALNS 
    solution = ALNS(scenario,initialSolution, requestBank,configuration,parameters, fileName)

    return solution
end

using JSON, Dates


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

end