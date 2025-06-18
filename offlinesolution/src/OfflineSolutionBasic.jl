module OfflineSolutionBasic

using ..ConstructionHeuristic
using alns
using domain
using Plots

export offlineSolution, inHindsightSolution, createGantChartOfSolutionOffline
#-------
# Determine offline solution without anticipation
#-------
function offlineSolution(scenario::Scenario,repairMethods::Vector{GenericMethod},destroyMethods::Vector{GenericMethod},parametersFile::String,alnsParameters::String,scenarioName::String;displayALNSPlots::Bool = false, saveALNSResults::Bool = false, outputFileFolder::String = "runfiles/output/OfflineSimulation", printResults::Bool = false,splitRequestBank::Bool=true)

    # Get solution for initial solution (offline problem)
    initialSolution, initialRequestBank = simpleConstruction(scenario,scenario.offlineRequests) 
        
    # Run ALNS for offline solution 
    solution,requestBank,_,_,_,_,_, noIterations = runALNS(scenario, scenario.requests, destroyMethods,repairMethods;parametersFile=alnsParameters,initialSolution =  initialSolution, requestBank = initialRequestBank, displayPlots = displayALNSPlots, saveResults = saveALNSResults,outPutFileFolder=outputFileFolder,splitRequestBank=splitRequestBank, stage="Offline")

    return solution, requestBank,noIterations

end

#-------
# Determine in-hindsight solution
#-------
function inHindsightSolution(scenario::Scenario,repairMethods::Vector{GenericMethod},destroyMethods::Vector{GenericMethod},parametersFile::String,alnsParameters::String,scenarioName::String;displayALNSPlots::Bool = false, saveALNSResults::Bool = false, outputFileFolder::String = "runfiles/output/OfflineSimulation", printResults::Bool = false, displayPlots::Bool = false)

    # Get solution for initial solution (offline problem)
    initialSolution, initialRequestBank = simpleConstruction(scenario,scenario.requests) 
        
    # Run ALNS for offline solution 
    solution,requestBank,_,_,_,_,_, noIterations = runALNS(scenario, scenario.requests, destroyMethods,repairMethods; event = scenario.onlineRequests[end],parametersFile=alnsParameters,initialSolution =  initialSolution, requestBank = initialRequestBank, displayPlots = displayALNSPlots, saveResults = saveALNSResults,outPutFileFolder=outputFileFolder, stage="Offline")

    if displayPlots
        display(createGantChartOfSolutionOffline(solution,"In-hindsigt solution",nFixed=scenario.nFixed))
    end 

    # Print summary 
    println(rpad("Metric", 40), "Value")
    println("-"^45)
    println(rpad("Unserviced requests", 40), length(requestBank),"/",(length(scenario.requests)))
    println(rpad("Final cost", 40), solution.totalCost)
    println(rpad("Final distance", 40), solution.totalDistance)
    println(rpad("Final ride time (veh)", 40), solution.totalRideTime)
    println(rpad("Final idle time", 40), solution.totalIdleTime)

    return solution, requestBank, noIterations

end

function createGantChartOfSolutionOffline(solution::Solution,title::String;nFixed::Int=0)
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []
    
    p = plot(size=(1500,1500))
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            isExpected = nFixed < assignment.activity.requestId 
            if assignment.activity.activityType == PICKUP
                if isExpected
                    color = :gold
                else
                    color = :lightgreen 
                end 
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("PU"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                if isExpected
                    color = :gold
                else
                    color = :tomato 
                end 
                
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("DO"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = :black
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D"*string(schedule.vehicle.depotId), :white, 8))
            else
                offset = 0
                color = :gray67
                markersize = 15

                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos], linewidth=29.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("W"*string(assignment.activity.location.name), :black, 8))

            end

            push!(xPositions, assignment.startOfServiceTime)
            push!(xLabels, string(round(assignment.startOfServiceTime/60.0,digits = 1)))

        end
        hline!([yPos - 1], linewidth=1, color=:gray, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 2
    end

    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels), xrotation=90)
    xlabel!("Time (Hour)")
    title!(string(title," - Activity Assignments for Vehicles"))
    
    return p
end

end