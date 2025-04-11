module OnlineSolutionResults

using Plots 
using domain, utils 

export createGantChartOfSolutionOnline


# Plot vehicle schedules 
# Define a function to plot activity assignments for each vehicle
function createGantChartOfSolutionOnline(solution::Solution,title::String;eventId::Int=-10,eventTime::Int=-10)
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []
    
    p = plot(size=(1500,1500))
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            if assignment.activity.activityType == PICKUP
                color = assignment.activity.requestId == eventId ? :lightblue1 : :lightgreen 
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("PU"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                color = assignment.activity.requestId == eventId ? :blue : :tomato
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("DO"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = :black
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D"*string(schedule.vehicle.id), :white, 8))
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
    
    if eventTime != -10 
        vline!([eventTime],lineWidth=1, color=:red, label="")
    end

    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels), xrotation=90)
    xlabel!("Time (Hour)")
    title!(string(title," - Activity Assignments for Vehicles"))
    
    return p
end



end