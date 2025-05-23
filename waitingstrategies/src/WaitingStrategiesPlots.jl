module WaitingStrategiesPlots

using Plots, domain

export plotRequestsAndVehiclesWait

function plotRequestsAndVehiclesWait(scenario,grid,n,gamma)
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


end