

using DataFrames, CSV, domain
using utils


function getTimeDistanceMatrix(requestFile::String, vehicleFile::String, parametersFile::String,dataName::String)
    # Check that files exist 
    if !isfile(requestFile)
        error("Error: Request file $requestFile does not exist.")
    end
    if !isfile(vehicleFile)
        error("Error: Vehicle file $vehicleFile does not exist.")
    end
    if !isfile(parametersFile)
        error("Error: Parameters file $parametersFile does not exist.")
    end

    # Read input 
    requestsDf = CSV.read(requestFile, DataFrame)
    vehiclesDf = CSV.read(vehicleFile, DataFrame)
    parametersDf = CSV.read(parametersFile, DataFrame)

    nRequests = nrow(requestsDf)
    nVehicles = nrow(vehiclesDf)

    # Get parameters 
    planningPeriod = TimeWindow(parametersDf[1,"start_of_planning_period"],parametersDf[1,"end_of_planning_period"])
    serviceTimes = Dict{MobilityType,Int}(WALKING => parametersDf[1,"service_time_walking"], WHEELCHAIR => parametersDf[1,"service_time_wheelchair"])
    vehicleCostPrHour = parametersDf[1,"vehicle_cost_pr_hour"]
    vehicleStartUpCost = parametersDf[1,"vehicle_start_up_cost"]
    bufferTime = parametersDf[1,"buffer_time"]
    maximumRideTimePercent = parametersDf[1,"maximum_ride_time_percent"]
    minimumMaximumRideTime = parametersDf[1,"minimum_maximum_ride_time"]


    # Get vehicles 
    vehicles = readVehicles(vehiclesDf,nVehicles,nRequests)

    # Get requests 
    requests = readRequests(requestsDf,bufferTime,maximumRideTimePercent,minimumMaximumRideTime)

    # Split into offline and online requests
    onlineRequests, offlineRequests = splitRequests(requests)

    # Get distance and time matrix
    scenario = Scenario(requests,onlineRequests,offlineRequests,serviceTimes,vehicles,vehicleCostPrHour,vehicleStartUpCost,planningPeriod,bufferTime,maximumRideTimePercent,minimumMaximumRideTime,zeros(Int, 0, 0),zeros(Int, 0, 0))
    distanceMatrix, timeMatrix = getDistanceAndTimeMatrix(scenario)

    open("Data/Matrices/timeMatrix_" * string(dataName) * ".txt", "w") do file
        for row in eachrow(timeMatrix)
            println(file, join(row, " "))  # Write each row as space-separated values
        end
    end

    open("Data/Matrices/distanceMatrix_" * string(dataName) * ".txt", "w") do file
        for row in eachrow(distanceMatrix)
            println(file, join(row, " "))  # Write each row as space-separated values
        end
    end


end


#getTimeDistanceMatrix("tests/resources/Requests.csv", "tests/resources/Vehicles.csv", "tests/resources/Parameters.csv", "Small")
getTimeDistanceMatrix("Data/Konsentra/TransformedData_Data.csv", "tests/resources/Vehicles.csv", "tests/resources/Parameters.csv", "Konsentra")