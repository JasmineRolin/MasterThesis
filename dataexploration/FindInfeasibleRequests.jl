

using domain, utils


function checkFeasibility(n, i, vehiclesFile, parametersFile)
    requestFile = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
    distanceMatrixFile = string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_distance.txt")
    timeMatrixFile =  string("Data/Matrices/",n,"/GeneratedRequests_",n,"_",i,"_time.txt")
    scenarioName = string("Konsentra_Data_",n,"_",i)

    scenario = readInstance(requestFile, vehiclesFile, parametersFile, scenarioName, distanceMatrixFile, timeMatrixFile)
    requests = scenario.requests
    vehicles = scenario.vehicles
    distance = scenario.distance

    noInfeasible = 0

    for r in requests
        hasFeasibleVehicle = false

        if r.requestType == PICKUP_REQUEST
            pickUpTime = r.pickUpActivity.timeWindow.startTime
        else
            pickUpTime = r.pickUpActivity.timeWindow.startTime + (r.maximumRideTime - r.directDriveTime)
        end

        for v in vehicles
            # If request is completely outside vehicle's time window, skip it
            if r.pickUpActivity.timeWindow.startTime > v.availableTimeWindow.endTime || r.dropOffActivity.timeWindow.endTime < v.availableTimeWindow.startTime
                continue
            end

            # Check if total travel time fits in the vehicle's available window
            earliestArrival = pickUpTime + r.directDriveTime + distance[r.dropOffActivity.id, v.id]

            earliestArrivalFromDepot = max(v.availableTimeWindow.startTime + distance[v.id,r.pickUpActivity.id],pickUpTime)
            if earliestArrivalFromDepot + r.directDriveTime + distance[r.dropOffActivity.id, v.id] > v.availableTimeWindow.endTime
                continue
            end

            if earliestArrival <= v.availableTimeWindow.endTime
                hasFeasibleVehicle = true
                break  # No need to check more vehicles if one is feasible
            end
        end

        if !hasFeasibleVehicle
            noInfeasible += 1
        end
    end

    println("Number of infeasible requests: ", noInfeasible)
end


n = 20
Gamma = 0.5
for i in 1:10
    vehiclesFile = string("Data/Konsentra/",n,"/Vehicles_",n,"_",Gamma,".csv")
    parametersFile = "tests/resources/Parameters.csv"
    checkFeasibility(n, i, vehiclesFile, parametersFile)
end
