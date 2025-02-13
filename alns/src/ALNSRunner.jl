module ALNSRunner

using domain, UnPack, ..ALNSParameters, ..ALNSConfiguration, ..ALNSAlgorithm

#==
 Module to run ALNS algorithm 
==#

function runALNS(scenario::Scenario, parametersFile::String)
    # Unpack scenario
    @unpack requests, onlineRequests, offlineRequests, serviceTimes, vehicles, vehicleCostPrHour, vehicleStartUpCost,planningPeriod = scenario

    # Read parameters 
    parameters = readParameters(parametersFile)

    # Create ALNS configuration 
    configuration = ALNSConfiguration(parameters)
    # TODO: add destroy and repair methods 

    # Construct initial solution 
    # TODO: construct initial solution 

    # Call ALNS 
    # solution = ALNS()


end


end