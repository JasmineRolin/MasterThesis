

using DataFrames, CSV, domain
using utils


function getTimeDistanceMatrix(requestFile::String, vehicleFile::String,dataName::String)
    # Check that files exist 
    if !isfile(requestFile)
        error("Error: Request file $requestFile does not exist.")
    end
    if !isfile(vehicleFile)
        error("Error: Vehicle file $vehicleFile does not exist.")
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

   mkpath(dirname(string(dataName) * "_time.txt"))
   open(string(dataName) * "_time.txt", "w") do file
        for row in eachrow(timeMatrix)
            println(file, join(row, " "))  # Write each row as space-separated values
        end
    end

    mkpath(dirname(string(dataName) * "_distance.txt"))
    open(string(dataName) * "_distance.txt", "w") do file
        for row in eachrow(distanceMatrix)
            println(file, join(row, " "))  # Write each row as space-separated values
        end
    end


end


#Main execution to handle command-line arguments
# function main()
#     if length(ARGS) < 3
#         println("Usage: julia script.jl <request_file> <vehicle_file> <name>")
#         return
#     end

#     requestFile = ARGS[1]
#     vehicleFile = ARGS[2]
#     dataName = ARGS[3]

#     getTimeDistanceMatrix(requestFile, vehicleFile, dataName)
# end

# main()



files = ["Data", "06.02","09.01","16.01","23.01","30.01"]
for suff in files 
    requestFile = string("Data/Konsentra/TransformedData_",suff,".csv")
    vehicleFile = "Data/Konsentra/Vehicles_0.9.csv"
    dataName = string("Data/Matrices/Konsentra_",suff)
    getTimeDistanceMatrix(requestFile, vehicleFile, dataName)
end