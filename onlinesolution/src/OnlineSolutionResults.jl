module OnlineSolutionResults

using Plots, JSON, DataFrames, Random
using Plots.PlotMeasures
using domain, utils 

export createGantChartOfSolutionOnline, createGantChartOfSolutionOnlineComparison,writeOnlineKPIsToFile,processResults,createGantChartOfSolutionAndEventOnline, createGantChartOfSolutionAndEventOnlineComparison, plotRoutesOnline
export plotRelocation,createGantChartOfSolutionAnticipation,plotRelocation2

# Plot vehicle schedules 
# Define a function to plot activity assignments for each vehicle
function createGantChartOfSolutionOnline(solution::Solution,title::String,nRequests::Int;eventId::Int=-10,eventTime::Int=-10,nFixed::Int=0,inRequestBank::Bool=false,event::Request= Request())
    yPositions = []
    yLabels = []
    yPos = 1

    
    p = plot(size=(2000,1000),
    leftmargin=5mm,topmargin=7mm,rightmargin=5mm,bottommargin=20mm,
    legendfontsize = 17,
    ytickfont = font(16),
    xtickfont = font(16),
    xguidefont = font(18),
    titlefont = font(20))

    minimumTime = typemax(Int)

    nVehicles = length(solution.vehicleSchedules)
    if nVehicles < 10 
        lineWidthActivity = 25.5
        markersize = 20
        markersizeWaiting = 20
        lineWidthWaiting = 39.5
        lineOffSet = 0.5
    else
        lineWidthActivity = 11.5
        markersize = 15
        markersizeWaiting = 15
        lineWidthWaiting = 29.5
        lineOffSet = 1
    end

    annotateOffSet = 0
    

    # Go through waiting activities and plot them (to place behind others )
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            if assignment.startOfServiceTime < minimumTime
                minimumTime = assignment.startOfServiceTime
            end
            
            if assignment.activity.activityType == WAITING
                activityId = assignment.activity.id 

                if activityId <= nRequests
                    l = "p"*string(activityId)
                elseif activityId <= 2*nRequests
                    l = "d"*string(activityId)
                else
                    l = "D"*string(activityId)
                end

                color = :gray67
                annotatePlacement = assignment.startOfServiceTime + (assignment.endOfServiceTime - assignment.startOfServiceTime)/2.0
                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos], linewidth=lineWidthWaiting, label="", color=color, marker=:none,markerstrokewidth=0,markersize=markersizeWaiting,alpha=0.5)
                annotate!(p,annotatePlacement, yPos, text(l, :black, 8))
            end
        end

        if nVehicles < 10 
            yPos += 1
        else
            yPos += 2
        end
    end


    # Plot remaining activities
    yPos = 1
    for schedule in solution.vehicleSchedules
        if schedule.route[end].endOfServiceTime < eventTime
            hline!([yPos - lineOffSet], linewidth=1, color=:gray, label="")

            push!(yPositions, yPos)
            push!(yLabels, "Vehicle $(schedule.vehicle.id)")

            if nVehicles < 10 
                yPos += 1
            else
                yPos += 2
            end

            continue 
        end

        for assignment in schedule.route
            if assignment.startOfServiceTime < minimumTime
                minimumTime = assignment.startOfServiceTime
            end

            offset = 0 # TO offset waiting activities visually 
            isExpected = nFixed < assignment.activity.requestId 
            if assignment.activity.activityType == PICKUP
                if isExpected
                    color = :gold
                else
                    color = assignment.activity.requestId == eventId ? :lightblue1 : :lightgreen 
                end 

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=lineWidthActivity, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos+annotateOffSet, text("p"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                if isExpected
                    color = :gold
                else
                    color = assignment.activity.requestId == eventId ? :blue : :tomato 
                end 
                
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=lineWidthActivity, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos+annotateOffSet, text("d"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = :black

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=lineWidthActivity, label="", color=color, marker=:rect,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D"*string(schedule.vehicle.depotId), :white, 8))

            end
        end
        hline!([yPos - lineOffSet], linewidth=1, color=:gray, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")

        if nVehicles < 10 
            yPos += 1
        else
            yPos += 2
        end
    end
    
    if eventTime != -10 
        vline!([eventTime],lineWidth=1, color=:red, label="")
    end

    # Plot event if it is in request bank 
    if inRequestBank
        hline!([yPos - lineOffSet], linewidth=1, color=:gray, label="")

        # Plot the event
        offset = 0
        plot!(p, [event.pickUpActivity.timeWindow.startTime, event.pickUpActivity.timeWindow.endTime], [yPos, yPos], linewidth=lineWidthWaiting, label="Pick up", color = :green, marker=:none,markerstrokewidth=0,markersize=markersize,alpha=0.5)
        annotatePlacement = event.pickUpActivity.timeWindow.startTime + (event.pickUpActivity.timeWindow.endTime-event.pickUpActivity.timeWindow.startTime)/2.0
        annotate!(p,annotatePlacement, yPos, text("p"*string(event.id), :whblackite, 8))

        plot!(p, [event.dropOffActivity.timeWindow.startTime, event.dropOffActivity.timeWindow.endTime], [yPos+offset, yPos+offset], linewidth=lineWidthWaiting, label="Drop off", color = :red, marker=:none,markerstrokewidth=0,markersize=markersize,alpha=0.5)
        annotatePlacement = event.dropOffActivity.timeWindow.startTime + (event.dropOffActivity.timeWindow.endTime-event.dropOffActivity.timeWindow.startTime)/2.0
        annotate!(p, annotatePlacement, yPos, text("d"*string(event.id), :black, 8))

        push!(yPositions, yPos)
        push!(yLabels, "Request $(event.id)")
    end

    # x labels 
    xPositions = []
    xLabels = []
    startMinute= Int(Int(floor(minimumTime/60.0,digits = 0))*60)
    endMinutes = 1440 
    for i in startMinute:60:endMinutes
        h = Int(round(i/60.0,digits = 0))
        if h < 10
            label = string("0", h, ":00")
        else
            label = string(h, ":00")
        end
        push!(xLabels, label)
        push!(xPositions, i)
    end

    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels), xrotation=90)
    xlabel!("Time (Hour)")
    xlims!(startMinute, endMinutes+10)
    title!(title)
    
    return p
end

#==
 Plot gantt chart and display changes between two solutions
==#
function createGantChartOfSolutionOnlineComparison(newSolution::Solution, oldSolution::Solution, title::String; eventId::Int = -10, eventTime::Int = -10)
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []

    p = plot(size = (1500, 1500))

    # Helper to extract a comparable representation of all assignments
    function extractActivityKeys(sol::Solution)
        keys = Set{Tuple}()
        for schedule in sol.vehicleSchedules
            for a in schedule.route
                key = (schedule.vehicle.id, a.activity.activityType, a.activity.requestId, round(a.startOfServiceTime; digits=2))
                push!(keys, key)
            end
        end
        return keys
    end

    oldKeys = extractActivityKeys(oldSolution)
    newKeys = extractActivityKeys(newSolution)

    changedKeys = setdiff(union(oldKeys, newKeys), intersect(oldKeys, newKeys))

    for schedule in newSolution.vehicleSchedules
        for assignment in schedule.route
            offset = 0
            key = (schedule.vehicle.id, assignment.activity.activityType, assignment.activity.requestId, round(assignment.startOfServiceTime; digits=2))
            isChanged = key in changedKeys

            if assignment.activity.activityType == PICKUP
                color = assignment.activity.requestId == eventId ? :lightblue1 : (isChanged ? :yellow : :lightgreen)
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("PU" * string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                color = assignment.activity.requestId == eventId ? :blue : (isChanged ? :yellow : :tomato)
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("DO" * string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = isChanged ? :yellow : :black
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D" * string(schedule.vehicle.depotId), :white, 8))

            else
                offset = 0
                color = isChanged ? :yellow : :gray67
                markersize = 15
                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos], linewidth=29.5, label="", color=color, marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("W" * string(assignment.activity.location.name), :black, 8))
            end

            push!(xPositions, assignment.startOfServiceTime)
            push!(xLabels, string(round(assignment.startOfServiceTime / 60.0, digits = 1)))
        end
        hline!([yPos - 1], linewidth = 1, color = :gray, label = "")
        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 2
    end

    if eventTime != -10
        vline!([eventTime], lineWidth = 1, color = :red, label = "")
    end

    plot!(p, yticks = (yPositions, yLabels))
    plot!(p, xticks = (xPositions, xLabels), xrotation = 90)
    xlabel!("Time (Hour)")
    title!(string(title, " - Activity Assignments for Vehicles"))

    return p
end


#==
 Plot routes 
==#
function plotRoutesOnline(solution::Solution,scenario::Scenario,requestBank::Vector{Int},event::Request,title::String)

    p = plot(size = (2000, 1500),bottom_margin=12mm, left_margin=12mm,
    top_margin=5mm, right_margin=5mm)

    # Bounding box
    maxLong = scenario.grid.maxLong
    minLong = scenario.grid.minLong
    maxLat = scenario.grid.maxLat
    minLat = scenario.grid.minLat
    nRows = scenario.grid.nRows
    nCols = scenario.grid.nCols
    latStep = scenario.grid.latStep
    longStep = scenario.grid.longStep

    lons = [minLong, maxLong, maxLong, minLong, minLong]
    lats = [minLat, minLat, maxLat, maxLat, minLat]
    plot!(p, lons, lats, label = "", color = :green, linewidth = 2)

    # Grid lines
    for lat in [minLat + i * latStep for i in 0:nRows]
        plot!(p, [minLong, maxLong], [lat, lat], color = :gray, linestyle = :dash, label = "")
    end
    for lon in [minLong + j * longStep for j in 0:nCols]
        plot!(p, [lon, lon], [minLat, maxLat], color = :gray, linestyle = :dash, label = "")
    end

    # Plot grid cell centers
    for loc in values(scenario.depotLocations)
        lat = loc.lat
        lon = loc.long
        scatter!(p, [lon], [lat], color = :gray, marker = (:cross, 4), label = "")
    end

    # Retrieve assigned requests
    firstPickUp = true 
    firstDropoff = true 
    firstDepot = true 
    firstWaiting = true 
    offset = 0.02
    assignedRequests = Vector{Int}()

    # Plot routes 
    palette_func = palette(:rainbow, length(solution.vehicleSchedules))
    colors = [palette_func[i] for i in 1:length(solution.vehicleSchedules)]
    colors = shuffle(colors)

    arrow_scale = 0.8 
    for (i, vehicleSchedule) in enumerate(solution.vehicleSchedules)
        routeLats = [v.activity.location.lat for v in vehicleSchedule.route]
        routeLongs = [v.activity.location.long for v in vehicleSchedule.route]

        # Cycle through colors if there are more vehicles than colors
        c = colors[i]

        plot!(routeLongs, routeLats, label = "Vehicle $i", color = c, linewidth = 2)
        # Plot arrows (quiver from each point to the next)
        for j in 1:(length(routeLats)-1)
            y = routeLats[j]
            x = routeLongs[j]
            dx = routeLongs[j+1] - x
            dy = routeLats[j+1] - y
            quiver!([x], [y], quiver=([arrow_scale * dx], [arrow_scale * dy]), color=c, arrow=:small, linewidth=1)
        end
    end

    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            if assignment.activity.activityType == PICKUP
                push!(assignedRequests, assignment.activity.requestId)

                
            end

            if assignment.activity.activityType == PICKUP
                if firstPickUp
                    firstPickUp = false 
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "Pick Up", color = :lightgreen, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(r.pickUpActivity.location.long, r.pickUpActivity.location.lat+offset, text("PU$(r.id)", :center, 8, color = :green))
                else
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "", color = :lightgreen, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(r.pickUpActivity.location.long, r.pickUpActivity.location.lat+offset, text("PU$(r.id)", :center, 8, color = :green))
                end
            elseif assignment.activity.activityType == DROPOFF
                if firstDropoff
                    firstDropoff = false
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "Drop off", color = :darkgreen, markersize = 10, marker = :square,markerstrokewidth=0)
                    annotate!(r.dropOffActivity.location.long, r.dropOffActivity.location.lat+offset, text("DO$(r.id)", :center, 8, color = :green))
                else 
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "", color = :darkgreen, markersize = 10, marker = :square,markerstrokewidth=0)
                    annotate!(r.dropOffActivity.location.long, r.dropOffActivity.location.lat+offset, text("DO$(r.id)", :center, 8, color = :green))
                end
            elseif assignment.activity.activityType == DEPOT
                if firstDepot
                    firstDepot = false
                    v = schedule.vehicle
                    scatter!([v.depotLocation.long], [v.depotLocation.lat], label = "Depot", color = :black, markersize = 12, marker = :star,markerstrokewidth=0)
                    annotate!(v.depotLocation.long, v.depotLocation.lat+offset, text("D$(v.id)", :center, 8, color = :black))
                else
                    v = schedule.vehicle
                    scatter!([v.depotLocation.long], [v.depotLocation.lat], label = "", color = :black, markersize = 12, marker = :star,markerstrokewidth=0)
                    annotate!(v.depotLocation.long, v.depotLocation.lat+offset, text("D$(v.id)", :center, 8, color = :black))
                end
            else
                if firstWaiting
                    firstWaiting = false
                    scatter!([assignment.activity.location.long], [assignment.activity.location.lat], label = "Waiting", color = :grey, markersize = 10, marker = :diamond,markerstrokewidth=0)
                    annotate!(assignment.activity.location.long, assignment.activity.location.lat+offset, text("W$(assignment.activity.id)", :center, 8, color = :grey))
                else 
                    scatter!([assignment.activity.location.long], [assignment.activity.location.lat], label = "", color = :grey, markersize = 10, marker = :diamond,markerstrokewidth=0)
                    annotate!(assignment.activity.location.long,assignment.activity.location.lat+offset, text("W$(assignment.activity.id)", :center, 8, color = :grey))
                end
            end
        end
    end

    # Event 
    if event.id != 0
        r = event
        scatter!([r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "PU Event", color = :magenta2, markersize = 10, marker = :circle,markerstrokewidth=0)
        annotate!(r.pickUpActivity.location.long, r.pickUpActivity.location.lat+offset, text("PU$(r.id)", :center, 8, color = :magenta2))
        scatter!([r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "DO Event", color = :magenta2, markersize = 10, marker = :square,markerstrokewidth=0)
        annotate!(r.dropOffActivity.location.long, r.dropOffActivity.location.lat+offset, text("DO$(r.id)", :center, 8, color = :magenta2))
    end
   

    title!(title)
    xlabel!("Longitude")
    ylabel!("Latitude")
    return p 
end



function createGantChartOfSolutionAndEventOnlineComparison(newSolution::Solution, oldSolution::Solution, title::String;
    eventId::Int = -10, eventTime::Int = -10, event::Request = Request())
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []

    p = plot(size = (1500, 1500))

    # Helper to get comparable activity keys
    function extractActivityKeys(sol::Solution)
    keys = Set{Tuple}()
    for schedule in sol.vehicleSchedules
        for a in schedule.route
            key = (schedule.vehicle.id, a.activity.activityType, a.activity.requestId, round(a.startOfServiceTime; digits=2))
            push!(keys, key)
        end
    end
    return keys
    end

    oldKeys = extractActivityKeys(oldSolution)
    newKeys = extractActivityKeys(newSolution)
    changedKeys = setdiff(union(oldKeys, newKeys), intersect(oldKeys, newKeys))

    for schedule in newSolution.vehicleSchedules
        for assignment in schedule.route
            key = (schedule.vehicle.id, assignment.activity.activityType, assignment.activity.requestId, round(assignment.startOfServiceTime; digits=2))
            isChanged = key in changedKeys

            color = :gray
            markersize = 15
            labelText = ""

            if assignment.activity.activityType == PICKUP
                color = assignment.activity.requestId == eventId ? :lightblue1 : (isChanged ? :yellow : :lightgreen)
                labelText = "PU" * string(assignment.activity.requestId)
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color,
                marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text(labelText, :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                color = assignment.activity.requestId == eventId ? :blue : (isChanged ? :yellow : :tomato)
                labelText = "DO" * string(assignment.activity.requestId)
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color,
                marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text(labelText, :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = isChanged ? :yellow : :black
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color,
                marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D" * string(schedule.vehicle.depotId), :white, 8))
                scatter!(p, [assignment.activity.timeWindow.startTime], [yPos], linewidth=11.5, label="",
                color=:darkgray, marker=:circle, markerstrokewidth=0, markersize=7)
                scatter!(p, [assignment.activity.timeWindow.endTime], [yPos], linewidth=11.5, label="",
                color=:darkgray, marker=:circle, markerstrokewidth=0, markersize=7)

            else
                color = isChanged ? :yellow : :gray67
                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos],
                linewidth=29.5, label="", color=color, marker=:square, markerstrokewidth=0, markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("W" * string(assignment.activity.location.name), :black, 8))
            end

            push!(xPositions, assignment.startOfServiceTime)
            push!(xLabels, string(round(assignment.startOfServiceTime / 60.0, digits = 1)))
        end

        hline!([yPos - 1], linewidth = 1, color = :gray, label = "")
        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 2
    end

    if eventTime != -10
    vline!([eventTime], lineWidth = 1, color = :red, label = "")
    end

    # Plot the incoming event
    offset = 0
    markersize = 10
    plot!(p, [event.pickUpActivity.timeWindow.startTime, event.pickUpActivity.timeWindow.endTime],
    [yPos, yPos], linewidth=19.5, label="Pick up", color=:green, marker=:square,
    markerstrokewidth=0, markersize=markersize)
    plot!(p, [event.dropOffActivity.timeWindow.startTime, event.dropOffActivity.timeWindow.endTime],
    [yPos, yPos], linewidth=19.5, label="Drop off", color=:red, marker=:square,
    markerstrokewidth=0, markersize=markersize)
    scatter!(p, [event.callTime], [yPos], linewidth=11.5, label="Call time", color=:blue,
    marker=:circle, markerstrokewidth=0, markersize=markersize)

    push!(yPositions, yPos)
    push!(yLabels, "Event $(event.id)")

    plot!(p, yticks = (yPositions, yLabels))
    plot!(p, xticks = (xPositions, xLabels), xrotation = 90)
    xlabel!("Time (Hour)")
    title!(string(title, " - Activity Assignments for Vehicles"))

    return p
end


function createGantChartOfSolutionAnticipation(scenario::Scenario,solution::Solution,title::String,nFixed::Int,requestBank::Vector{Int})
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []
    
    p = plot(size=(1500,1500))

    yInc = nFixed >= 300 ? 4 : 2
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            if assignment.activity.activityType == PICKUP
                color = assignment.activity.requestId > nFixed ? :purple : :lightgreen 
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("PU"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                color = assignment.activity.requestId > nFixed ? :blue : :tomato
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("DO"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = :black
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D"*string(schedule.vehicle.depotId), :white, 8))
                scatter!(p, [assignment.activity.timeWindow.startTime], [yPos], linewidth=11.5, label="", color=:darkgray, marker=:circle,markerstrokewidth=0,markersize=7)
                scatter!(p, [assignment.activity.timeWindow.endTime], [yPos], linewidth=11.5, label="", color=:darkgray, marker=:circle,markerstrokewidth=0,markersize=7)
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
        yPos += yInc
    end

    # Plot the event
    for r in requestBank
        event = scenario.requests[r]
        offset = 0
        markersize = 10
        colorPU = r > nFixed ? :purple : :lightgreen 
        colorDO = r > nFixed ? :blue : :tomato

        plot!(p, [event.pickUpActivity.timeWindow.startTime, event.pickUpActivity.timeWindow.endTime], [yPos, yPos], linewidth=19.5, label="", color = colorPU, marker=:square,markerstrokewidth=0,markersize=markersize)
        plot!(p, [event.dropOffActivity.timeWindow.startTime, event.dropOffActivity.timeWindow.endTime], [yPos, yPos], linewidth=19.5, label="", color = colorDO, marker=:square,markerstrokewidth=0,markersize=markersize)
        push!(yPositions, yPos)
        push!(yLabels, "Event $(event.id)")
        yPos += yInc

    end

    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels), xrotation=90)
    xlabel!("Time (Hour)")
    title!(string(title," - Activity Assignments for Vehicles"))
    
    return p
end


#==
 Plot relocation event
==#
function plotRelocation(predictedDemand,activeVehiclesPerCell,realisedDemand,vehicleBalance,gridCell,depotGridCell,period,periodLength,vehicle,vehicleDemand)
    avg_min = min(minimum(vehicleBalance),minimum(activeVehiclesPerCell))
    avg_max = max(maximum(activeVehiclesPerCell),maximum(vehicleBalance))

    demand_min = min(minimum(predictedDemand),minimum(realisedDemand))
    demand_max = max(maximum(predictedDemand),maximum(realisedDemand))
    
    # Plot for chosen period 
    p2 = heatmap(activeVehiclesPerCell[period,:,:], 
    clim=(avg_min, avg_max),
    c=:viridis,         # color map
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Vehicles per Grid Cell in solution",
    colorbar_title="Vehicle Demand")
    scatter!(p2,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="New waiting location", color=:green)
    scatter!(p2,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Previous waiting location", color=:red)


    p3 = heatmap(vehicleBalance[period,:,:], 
    c=:viridis,         # color map
    clim=(avg_min, avg_max),
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Vehicle balance",
    colorbar_title="Vehicle Demand")
    scatter!(p3,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="New waiting location", color=:green)
    scatter!(p3,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Previous waiting location", color=:red)

    p4 = heatmap(vehicleDemand[period,:,:], 
    c=:viridis,         # color map
    clim=(avg_min, avg_max),
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Vehicle demand",
    colorbar_title="Vehicle Demand")
    scatter!(p4,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="New waiting location", color=:green)
    scatter!(p4,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Previous waiting location", color=:red)

    # Find predicted vehicle demand for each hour 
    planningHorizon = 4
    nTimePeriods = size(predictedDemand,1)
    endPeriod = min(period + planningHorizon, nTimePeriods)
    maxDemandInHorizon = maximum(predictedDemand[period:endPeriod,:,:], dims=1)
    maxDemandInHorizon = dropdims(maxDemandInHorizon, dims=1)

    p5 = heatmap(maxDemandInHorizon[:,:], 
    c=:viridis,         # color map
    clim=(demand_min, demand_max),
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Demand over horizon",
    colorbar_title="Requests")
    scatter!(p5,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="New waiting location", color=:green)
    scatter!(p5,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Previous waiting location", color=:red)


    super_title = plot(title = "Vehicle relocation: period start: $((period-1)*periodLength), vehicle:  $(vehicle.id)", grid=false, framestyle=:none)

    # Combine all into a vertical layout: super title + 3 plots
    p = plot(super_title, plot(p2, p3,p4,p5, layout=(2,2)), layout = @layout([a{0.01h}; b{0.99h}]), size=(1500,1100))

    return p
end


function plotRelocation2(probabilityGrid,score,activeVehiclesPerCell,gridCell,depotGridCell,period,periodLength,vehicle)
    avg_min = minimum(activeVehiclesPerCell)
    avg_max = maximum(activeVehiclesPerCell)

    activeVehiclesInPeriod = activeVehiclesPerCell[period, :, :]

    p1 = heatmap(activeVehiclesInPeriod, 
    clim=(avg_min, avg_max),
    c=:viridis,         # color map
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Vehicles per Grid Cell in solution",
    colorbar_title="Vehicle balance")
    scatter!(p1,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:green)
    scatter!(p1,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Depot location", color=:red)

    p2 = heatmap(probabilityGrid[:,:], 
    c=:viridis,         # color map
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Probability grid",
    colorbar_title="Probability")
    scatter!(p2,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:green)
    scatter!(p2,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Depot location", color=:red)

    p3 = heatmap(score, 
    c=:viridis,         # color map
    xlabel="Longitude (grid cols)", 
    ylabel="Latitude (grid rows)", 
    title="Score",
    colorbar_title="Score")
    scatter!(p3,[gridCell[2]],[gridCell[1]], marker = (:circle, 5), label="Waiting location", color=:green)
    scatter!(p3,[depotGridCell[2]],[depotGridCell[1]], marker = (:circle, 5), label="Depot location", color=:red)

    super_title = plot(title = "Vehicle Demand Overview - period start $((period-1)*periodLength), vehicle $(vehicle)", grid=false, framestyle=:none)

    # Combine all into a vertical layout: super title + 3 plots
    p = plot(super_title, plot(p1,p2,p3, layout=(1,3)), layout = @layout([a{0.01h}; b{0.99h}]), size=(1500,1100))

    return p
end


#==
 Write KPIs to file  
==#
function writeOnlineKPIsToFile(fileName::String, scenario::Scenario,solution::Solution,requestBank::Vector{Int}, requestBankOffline::Vector{Int},totalElapsedTime::Float64,averageResponseTime::Float64,eventsInsertedByALNS::Int,numberOfRequestsOverlapIdleVehicle::Int,driveTimeToNearestIdleVehicle::Int)
    # Find drive times for customers
    totalDirectRideTime = length(requestBank) == length(scenario.requests) ? 0 : sum(r.directDriveTime for r in scenario.requests if !(r.id in requestBank)) 
    totalActualRideTime = 0
    pickUpTimes = Dict{Int,Int}()
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            activity = assignment.activity
            if activity.activityType == PICKUP
                pickUpTimes[activity.requestId] = assignment.endOfServiceTime
            elseif activity.activityType == DROPOFF
                pickupTime = pickUpTimes[activity.requestId]
                dropoffTime = assignment.startOfServiceTime
                totalActualRideTime += dropoffTime - pickupTime
            end
        end
    end

    # Find idle time with customers 
    totalIdleTimeWithCustomer = 0 
    for schedule in solution.vehicleSchedules
        for (idx,assignment) in enumerate(schedule.route)
            if assignment.activity.activityType == WAITING && schedule.numberOfWalking[idx] > 0
                totalIdleTimeWithCustomer += assignment.endOfServiceTime - assignment.startOfServiceTime
            end
        end
    end

    # Find percent of ride sharing 
    averagePercentRideSharing = 0.0 
    for schedule in solution.vehicleSchedules
        if (length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT) || (sum(schedule.numberOfWalking .> 0) == 0)
            continue
        end
        noPassengers = sum(schedule.numberOfWalking .> 0)
        noRideSharing = sum(schedule.numberOfWalking .> 1)

        if noPassengers != 0
            averagePercentRideSharing += noRideSharing/noPassengers
        end
    end
    averagePercentRideSharing = (averagePercentRideSharing/length(solution.vehicleSchedules))*100.0

    # Find total duration of empty drive time to/from waiting locations 
    totalEmptyRelocationTime = 0
    for schedule in solution.vehicleSchedules
        for (idx,assignment) in enumerate(schedule.route)
            if assignment.activity.activityType == WAITING && schedule.numberOfWalking[idx] == 0
                currentActivity = assignment.activity.id 

                # Drive time from activity before 
                activityBefore = schedule.route[idx-1].activity.id
                totalEmptyRelocationTime += scenario.time[activityBefore, currentActivity]

                # If next activity is not waiting (otherwise time is counted twice) or depot (since this is unavoidable)
                if schedule.route[idx+1].activity.activityType != WAITING && schedule.route[idx+1].activity.activityType != DEPOT
                    nextActivity = schedule.route[idx+1].activity.id
                    totalEmptyRelocationTime += scenario.time[currentActivity, nextActivity]
                end
            end
        end
    end

    # Create a dictionary for the entire KPIs
    KPIDict = Dict(
        "Scenario" => Dict("name" => scenario.name),
        "TotalCost" => solution.totalCost,
        "TotalDistance" => solution.totalDistance,
        "TotalRideTime" => solution.totalRideTime,
        "TotalIdleTime" => solution.totalIdleTime,
        "TotalIdleTimeWithCustomer" => totalIdleTimeWithCustomer,
        "nTaxi" => solution.nTaxi, 
        "nOfflineRequests" => length(scenario.offlineRequests),
        "nOnlineRequests" => length(scenario.onlineRequests),
        "UnservicedOfflineRequests" => length(requestBankOffline),
        "UnservicedOnlineRequests" => length(setdiff(requestBank, requestBankOffline)),
        "TotalDirectRideTime" => totalDirectRideTime,
        "TotalActualRideTime" => totalActualRideTime,
        "TotalElapsedTime" => round(totalElapsedTime,digits=2),
        "AverageResponseTime" => round(averageResponseTime,digits=2), 
        "EventsInsertedByALNS" => eventsInsertedByALNS,
        "AveragePercentRideSharing" => round(averagePercentRideSharing,digits=3), 
        "TotalEmptyRelocationTime" => totalEmptyRelocationTime,
        "TotalNumberOfRequestsOverlapIdleVehicle" => numberOfRequestsOverlapIdleVehicle, 
        "TotalDriveTimeToNearestIdleVehicle" => driveTimeToNearestIdleVehicle
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(KPIDict))
    close(file)

    return KPIDict
end 

#==
 Method to process results 
==#
function processResults(files::Vector{String})
    results = DataFrame(
        ScenarioName = String[],
        TotalElapsedTime = Float64[],
        AverageResponseTime = Float64[],
        EventsInsertedByALNS = Int[], 
        nTaxi = Int[],
        TotalCost = Float64[],
        TotalDistance = Float64[],
        TotalIdleTime = Int[],
        TotalIdleTimeWithCustomer= Int[],
        TotalRideTime= Int[], 
        TotalDirectRideTime= Int[], 
        TotalActualRideTime= Int[],
        nOfflineRequests= Int[], 
        UnservicedOfflineRequest= Int[],
        nOnlineRequests= Int[],
        UnservicedOnlineRequests= Int[],
        AveragePercentRideSharing = Float64[],
        ExcessRideTimePrServicedRequest = Float64[], 
        TotalEmptyRelocationTime = Int[], 
        TotalNumberOfRequestsOverlapIdleVehicle = Int[], 
        TotalDriveTimeToNearestIdleVehicle = Int[]
    )

    # Assuming you have multiple JSON files, you can read them like this
    appendResults(files,results)

    return results
end

# Create an empty DataFrame with the KPIs as camel case column names

# Function to read and append multiple JSON files to the DataFrame
function appendResults(files,results)
    for file_path in files
        if !isfile(file_path)
            println("File not found: ", file_path)
            continue
        end
        
        row = parse_json(file_path)
        push!(results, row)
    end
end



# Function to parse the JSON file and extract relevant information (camel case)
function parse_json(file_path)
    data = JSON.parsefile(file_path)
    
    # Extract values from the JSON structure with camel case keys
    scenarioName = data["Scenario"]["name"]
    totalIdleTime = data["TotalIdleTime"]
    eventsInsertedByALNS = data["EventsInsertedByALNS"]
    totalElapsedTime = data["TotalElapsedTime"]
    unservicedOnlineRequests = data["UnservicedOnlineRequests"]
    totalRideTime = data["TotalRideTime"]
    nTaxi = data["nTaxi"]
    unservicedOfflineRequests = data["UnservicedOfflineRequests"]
    averageResponseTime = data["AverageResponseTime"]
    totalIdleTimeWithCustomer = data["TotalIdleTimeWithCustomer"]
    totalDirectRideTime = data["TotalDirectRideTime"]
    nOnlineRequests = data["nOnlineRequests"]
    totalCost = data["TotalCost"]
    totalDistance = data["TotalDistance"]
    nOfflineRequests = data["nOfflineRequests"]
    totalActualRideTime = data["TotalActualRideTime"]
    averagePercentRideSharing = data["AveragePercentRideSharing"]
    totalEmptyRelocationTime = data["TotalEmptyRelocationTime"]
    totalNumberOfRequestsOverlapIdleVehicle = data["TotalDriveTimeToNearestIdleVehicle"]
    totalDriveTimeToNearestIdleVehicle = data["TotalDriveTimeToNearestIdleVehicle"]

    excessRideTime = totalActualRideTime- totalDirectRideTime
    excessRideTimePrServicedRequest = excessRideTime / (nOnlineRequests + nOfflineRequests)
    
    return [
       scenarioName,
        totalElapsedTime,
        averageResponseTime,
        eventsInsertedByALNS, 
        nTaxi,
        totalCost,
        totalDistance,
        totalIdleTime,
        totalIdleTimeWithCustomer,
        totalRideTime, 
        totalDirectRideTime, 
        totalActualRideTime,
        nOfflineRequests, 
        unservicedOfflineRequests,
        nOnlineRequests,
        unservicedOnlineRequests, 
        averagePercentRideSharing,
        excessRideTimePrServicedRequest,
        totalEmptyRelocationTime, 
        totalNumberOfRequestsOverlapIdleVehicle. 
        totalDriveTimeToNearestIdleVehicle
    ]
end

end