module OfflineSolutionBasic

using ..ConstructionHeuristic
using alns
using domain

export offlineSolution
#-------
# Determine offline solution with anticipation
#-------
function offlineSolution(scenario::Scenario,repairMethods::Vector{GenericMethod},destroyMethods::Vector{GenericMethod},parametersFile::String;displayALNSPlots::Bool = false, saveALNSResults::Bool = false, outputFileFolder::String = "runfiles/output/OfflineSimulation", printResults::Bool = false)

    # Get solution for initial solution (offline problem)
    initialSolution, initialRequestBank = simpleConstruction(scenario,scenario.offlineRequests) 
        
    # Run ALNS for offline solution 
    solution,requestBank = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile=parametersFile,initialSolution =  initialSolution, requestBank = initialRequestBank, displayPlots = displayALNSPlots, saveResults = saveALNSResults,outPutFileFolder=outputFileFolder)

    return solution, requestBank

end

end