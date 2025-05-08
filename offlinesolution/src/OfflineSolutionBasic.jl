

using ..ConstructionHeuristic
using alns

#-------
# Determine offline solution with anticipation
#-------
function offlineSolution(requestFile::String,vehiclesFile::String,parametersFile::String,alnsParameters::String,scenarioName::String)

    # Get solution for initial solution (offline problem)
    initialSolution, initialRequestBank = simpleConstruction(scenario,scenario.offlineRequests) 
        
    # Run ALNS for offline solution 
    # TODO: set correct parameters for alns
    solution,requestBank = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile="tests/resources/ALNSParameters_offline.json",initialSolution =  initialSolution, requestBank = initialRequestBank, displayPlots = displayALNSPlots, saveResults = saveALNSResults)

    return solution, requestBank

end