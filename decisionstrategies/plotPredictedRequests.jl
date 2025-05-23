

include("anticipation.jl")


test = createExpectedRequests(40,100)

#histogram(test[!,:request_time]./60)

# Files 
vehicleFile = string("Data/Konsentra/20/Vehicles_20_0.5.csv")
parametersFile = "tests/resources/Parameters.csv"
alnsParameters = "tests/resources/ALNSParameters3.json"
gridFile = "Data/Konsentra/grid.json"
requestFile = string("Data/Konsentra/20/GeneratedRequests_20_1.csv")

scenario = readInstanceAnticipation(requestFile,100, vehicleFile, parametersFile)

using Plots

function plot_request_gantt(scenario::Scenario)
    # Filter for non-fixed requests
    requests = filter(r -> r.id > scenario.nFixed, scenario.requests)
    n = length(requests)

    p = plot(size=(1200, max(400, 30n)))
    y_positions = reverse(1:n)
    y_labels = ["Req $(r.id)" for r in requests]

    for (i, req) in enumerate(requests)
        y = y_positions[i]

        # Pickup time window
        tw_pickup = req.pickUpActivity.timeWindow
        plot!([tw_pickup.startTime/60, tw_pickup.endTime/60], [y, y],
              linewidth=6, color=:blue, label=i==1 ? "Pickup Window" : "")

        # Dropoff time window
        tw_dropoff = req.dropOffActivity.timeWindow
        plot!([tw_dropoff.startTime/60, tw_dropoff.endTime/60], [y, y],
              linewidth=6, color=:green, label=i==1 ? "Dropoff Window" : "")
    end

    yticks!(y_positions, y_labels)
    xlabel!("Time (minutes after midnight)")
    ylabel!("Requests")
    title!("Request Gantt Chart")
    #legend(:bottomright)

    return p
end
plot_request_gantt(scenario)