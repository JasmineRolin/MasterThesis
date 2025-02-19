

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

    nRequests = nrow(requestsDf)

    # Locations 
    # Collect request info 
    pickUpLocations = [(r.pickup_latitude,r.pickup_longitude) for r in eachrow(requestsDf)]
    dropOffLocations = [(r.dropoff_latitude,r.dropoff_longitude)  for r in eachrow(requestsDf)]

    # Get vehicles 
    _, _, depotLocations = readVehicles(vehiclesDf,nRequests)

    # Collect all locations
    locations = [pickUpLocations;dropOffLocations;collect(keys(depotLocations))]


   distanceMatrix, timeMatrix = getDistanceAndTimeMatrixFromLocations(locations)

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