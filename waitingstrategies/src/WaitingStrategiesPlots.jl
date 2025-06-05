module WaitingStrategiesPlots

using Plots, domain, Plots.PlotMeasures

export plotRequestsAndVehiclesWait,plotScenario

function plotRequestsAndVehiclesWait(scenario,grid)
    max_lat = grid.maxLat 
    min_lat = grid.minLat
    max_long = grid.maxLong
    min_long = grid.minLong
    nRows = grid.nRows
    nCols = grid.nCols
    lat_step = grid.latStep
    long_step = grid.longStep

    p = plot(size = (1500, 1000))

    offset = 0.001

    # Plot first with label 
    r = scenario.requests[1]
    scatter!(p, [r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "Pick-up", color = :blue, markersize = 3)
    scatter!(p, [r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "Drop-off", color = :red, markersize = 3)
   
    annotate!(p, (r.pickUpActivity.location.long, r.pickUpActivity.location.lat-offset, text("PU$(r.id)", :blue, 8,:top)))
    annotate!(p, (r.dropOffActivity.location.long, r.dropOffActivity.location.lat-offset, text("DO$(r.id)", :red, 8,:top)))

    # Plot remaining requests without label
    for r in scenario.requests[2:end]
        scatter!(p, [r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "", color = :blue, markersize = 3)
        scatter!(p, [r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "", color = :red, markersize = 3)
       
        annotate!(p, (r.pickUpActivity.location.long, r.pickUpActivity.location.lat-offset, text("PU$(r.id)", :blue, 8,:top)))
        annotate!(p, (r.dropOffActivity.location.long, r.dropOffActivity.location.lat-offset, text("DO$(r.id)", :red, 8,:top)))
    end
  
    coord_counts = Dict{Tuple{Float64, Float64}, Int}()

    # Plot first vehicle with label
    v = scenario.vehicles[1]
    scatter!(p, [v.depotLocation.long],[v.depotLocation.lat], label = "Vehicles", color = :black, markersize = 5,marker=:square)

    pos = (v.depotLocation.long, v.depotLocation.lat)
    count = get!(coord_counts, pos, 0)
    y_offset = 0.01 * count  # tune this offset as needed
    annotate!(p, (v.depotLocation.long, v.depotLocation.lat + offset + y_offset, text("D$(v.id)", :black, 8,:bottom)))
    coord_counts[pos] += 1

    # Plot remaining vehicles without label
    for v in scenario.vehicles[2:end]
        scatter!(p, [v.depotLocation.long],[v.depotLocation.lat], label = "", color = :black, markersize = 5,marker=:square)

        pos = (v.depotLocation.long, v.depotLocation.lat)
        count = get!(coord_counts, pos, 0)
        y_offset = 0.01 * count  # tune this offset as needed
        annotate!(p, (v.depotLocation.long, v.depotLocation.lat + offset + y_offset, text("D$(v.id)", :black, 8,:bottom)))
        coord_counts[pos] += 1
    end
    
    # Bounding box
    lons = [min_long, max_long, max_long, min_long, min_long]
    lats = [min_lat, min_lat, max_lat, max_lat, min_lat]
    plot!(p, lons, lats, label = "", color = :green, linewidth = 2)

    # Grid lines
    for lat in [min_lat + i * lat_step for i in 0:nRows]
        plot!(p, [min_long, max_long], [lat, lat], color = :gray, linestyle = :dash, label = "")
    end
    for lon in [min_long + j * long_step for j in 0:nCols]
        plot!(p, [lon, lon], [min_lat, max_lat], color = :gray, linestyle = :dash, label = "")
    end

    # Plot grid cell centers
    for l in values(scenario.depotLocations)
        lat = l.lat
        lon = l.long
        scatter!(p, [lon], [lat], color = :gray, marker = (:cross, 4), label = "")
    end

    return p
end


#==
 Plot scenario with call times 
==#
function plotScenario(requests::Vector{Request}, title::String)
    requests = sort(requests, by = r -> r.pickUpActivity.timeWindow.startTime)
    n = length(requests)

    # Labels 
    labels = [string("Request ",r.id) for r in requests]

    # Times 
    start_times = [r.pickUpActivity.timeWindow.startTime for r in requests]
    end_times = [r.pickUpActivity.timeWindow.endTime for r in requests]
    call_times = [r.callTime for r in requests]
    durationsCallTime = end_times .- call_times
    durationsCallTimeStart = start_times .- call_times

    # Plotting
    p = plot(size = (1800,1200),legend=true, xlabel="Hour", 
        yticks=(1:n, labels), title=title,leftmargin=5mm,topmargin=5mm,rightmargin=5mm,bottommargin=7mm,
        legendfontsize = 17,
        ytickfont = font(14),
        xtickfont = font(14),
        xguidefont = font(16),
        titlefont = font(18))

    # Add bars for time windows
    for i in 1:n
        y = i # reverse order to show first request at the top
        if i == 1
            label = "Pickup Time Window"
        else
            label = ""
        end
        plot!([start_times[i], end_times[i]], [y, y], lw=10, color=:blue,label=label)
        annotate!([end_times[i]], [y+0.1], text("$(durationsCallTime[i])", :black, 12, :bottom))
        annotate!([start_times[i]], [y+0.1], text("$(durationsCallTimeStart[i])", :black, 12, :bottom))
    end

    # Add vertical red lines for call times
    firstPlot = true
    for i in 1:n
        y = i
        if i == 1
            label = "Call Time"
        else
            label = ""
        end
        plot!([call_times[i], call_times[i]], [y-0.3, y+0.3], color=:red, linestyle=:solid,label=label,linewidth=5)
    end

    # xticks 
    xlims!(p, 0, 1440) # 24 hours in minutes

    xPositions = []
    xLabels = []
    for i in 0:60:1440
        h = Int(round(i/60.0,digits = 0))
        if h < 10
            label = string("0", h, ":00")
        else
            label = string(h, ":00")
        end
        push!(xLabels, label)
        push!(xPositions, i)
    end

    plot!(p, xticks = (xPositions, xLabels), xrotation = 90)

    return p 
end


end