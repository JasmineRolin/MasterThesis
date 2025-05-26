using CSV, DataFrames, JSON
using Plots
using KernelDensity, Statistics
using Random
using StatsBase
using domain, utils
using Plots.PlotMeasures

include("GenerateAndSaveSimulationData.jl")
include("TransformKonsentraData.jl")
include("GenerateLargeVehiclesKonsentra.jl")
include("MakeAndSaveDistanceAndTimeMatrix.jl")
include("GenerateLargeDataSets.jl")


global GENERATE_SIMULATION_DATA = true
global GENERATE_DATA_AND_VEHICLES = true
global GENERATE_VEHICLES = false

#==
# Constants for data generation 
==#
global DoD = 0.6 # Degree of dynamism
global serviceWindow = [minutesSinceMidnight("06:00"), minutesSinceMidnight("23:00")]
global callBuffer = 60 # 2 hours buffer
global nData = 10
global nRequestList = 300#[20,100,300,500]
global MAX_DELAY = 60 # TODO Astrid I just put something
global earliestBuffer = 2*60

#==
# Constant for vehicle generation  
==#
global vehicleCapacity = 4
global GammaList = [0.5,0.7] 

# TODO: burde vi bare have flad cost ? vi er jo ligeglade med cost faktisk 
global shifts = Dict(
    "Morning"    => Dict("TimeWindow" => [6*60, 12*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Noon"       => Dict("TimeWindow" => [10*60, 16*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Afternoon"  => Dict("TimeWindow" => [14*60, 20*60], "cost" => 1.0, "nVehicles" => 0, "y" => []),
    "Evening"    => Dict("TimeWindow" => [18*60, 24*60], "cost" => 1.0, "nVehicles" => 0, "y" => [])
)


#==
# Grid constants 
==#
global MAX_LAT = 60.721
global MIN_LAT = 59.165
global MAX_LONG = 12.458
global MIN_LONG = 9.948
global NUM_ROWS = 10
global NUM_COLS = 10

#==
# Common 
==#
global time_range = collect(range(6*60,23*60))

#================================================================================================#
# Write grid to file 
#================================================================================================#
# Create a serializable dictionary
grid = Dict(
        "max_latitude" => MAX_LAT,
        "min_latitude" => MIN_LAT,
        "max_longitude" => MAX_LONG,
        "min_longitude" => MIN_LONG,
        "num_rows" => NUM_ROWS,
        "num_columns" => NUM_COLS
)

# Write to a JSON file
open("Data/Konsentra/grid_$(NUM_ROWS).json", "w") do f
    JSON.print(f, grid) 
end

#================================================================================================#
# Generate simulation data 
#================================================================================================#
oldDataList = ["Data/Konsentra/TransformedData_30.01.csv",
            "Data/Konsentra/TransformedData_06.02.csv",
            "Data/Konsentra/TransformedData_09.01.csv",
            "Data/Konsentra/TransformedData_16.01.csv",
            "Data/Konsentra/TransformedData_23.01.csv",
            "Data/Konsentra/TransformedData_Data.csv"]

# Smooting factors for KDE 
bandwidth_factor_time_offline = 1.0
bandwidth_factor_time_online = 1.5 
bandwidth_factor_location = 1.25
bandwidth_factor_distance = 2.0


if GENERATE_SIMULATION_DATA
    run_and_save_simulation(oldDataList, "Data/Simulation data/", bandwidth_factor_location, bandwidth_factor_time_offline, bandwidth_factor_time_online, bandwidth_factor_distance,time_range)
end



#================================================================================================#
# Generate data 
#================================================================================================#
if GENERATE_DATA_AND_VEHICLES
    lat_step, long_step, grid_centers = findGridCenters(MAX_LAT,MIN_LAT,MAX_LONG,MIN_LONG,NUM_ROWS,NUM_COLS)

    # Load simulation data
    _,
    _,
    _,
    base_probabilities_location,
    _,
    base_x_range,
    base_y_range,
    _,
    _,
    _,
    _,
    _,
    _,
    _= load_simulation_data("Data/Simulation data/")

    for nRequest in nRequestList
        location_matrix, requestTime, newDataList, df_list,probabilities_time,probabilities_offline,probabilities_online, probabilities_location, density_grid, x_range, y_range,requests, distanceDriven = generateDataSets(nRequest,DoD,nData,time_range,MAX_LAT, MIN_LAT, MAX_LONG, MIN_LONG)

        # Generate vehicles 
        for gamma in GammaList
            println("Gamma = ",gamma)

            # Generate vehicles
            average_demand_per_hour = generateVehicles(shifts,df_list, base_probabilities_location, base_x_range, base_y_range,gamma,vehicleCapacity,nRequest,MAX_LAT,MIN_LAT,MAX_LONG,MIN_LONG,NUM_ROWS,NUM_COLS)

            # Plot demand and shifts
            plotDemandAndShifts(average_demand_per_hour,shifts,gamma)

            # Plot request and vehicle locations 
            plotRequestsAndVehicles(nRequest,nData,gamma,MAX_LAT,MIN_LAT,MAX_LONG,MIN_LONG,NUM_ROWS,NUM_COLS,grid_centers,lat_step,long_step)
        end

        # Generate time and distance matrices  
        depotLocations = Vector{Tuple{Float64,Float64}}()
        [push!(depotLocations,(loc[1],loc[2])) for loc in grid_centers]
        for gamma in GammaList
            for i in 1:nData
                println("n = ",nRequest," i = ",i)
                requestFile = string("Data/Konsentra/",nRequest,"/GeneratedRequests_",nRequest,"_",i,".csv")
                dataName = string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",gamma,"_",i)
                
                getTimeDistanceMatrix(requestFile, depotLocations, dataName)
            end
        end


        #================================================#
        # Plot new data
        #================================================#
        createAndSavePlotsGeneratedData(newDataList,nRequest,x_range,y_range,density_grid,location_matrix,requestTime,probabilities_time, probabilities_offline,probabilities_online,serviceWindow,distanceDriven)
        for gamma in GammaList
            plotAndSaveGantChart(nRequest,nData,gamma)
        end
    end

   
end


#================================================================================================#
# Generate vehicles
#================================================================================================#
if GENERATE_VEHICLES
    lat_step, long_step, grid_centers = findGridCenters(MAX_LAT,MIN_LAT,MAX_LONG,MIN_LONG,NUM_ROWS,NUM_COLS)

    for nRequest in nRequestList
        # Load simulation data
        probabilities_pickUpTime,
        probabilities_dropOffTime,
        density_pickUp,
        density_dropOff,
        probabilities_location,
        density_grid,
        x_range,
        y_range,
        probabilities_distance,
        density_distance,
        distance_range,
        location_matrix,
        requestTimePickUp,
        requestTimeDropOff,
        requests,
        distanceDriven= load_simulation_data("Data/Simulation data/")

        # Read data
        df_list = load_request_data(nRequest,nData)

        # Generate vehicles 
        for gamma in GammaList
            println("Gamma = ",gamma)

            # Generate vehicles
            average_demand_per_hour = generateVehicles(shifts,df_list, probabilities_location, x_range, y_range,gamma,vehicleCapacity,nRequest,MAX_LAT,MIN_LAT,MAX_LONG,MIN_LONG,NUM_ROWS,NUM_COLS)

            plotDemandAndShifts(average_demand_per_hour,shifts,gamma)

            # Plot request and vehicle locations 
            plotRequestsAndVehicles(nRequest,nData,gamma,MAX_LAT,MIN_LAT,MAX_LONG,MIN_LONG,NUM_ROWS,NUM_COLS,grid_centers,lat_step,long_step)
        end

        # Generate time and distance matrices  
        depotLocations = Vector{Tuple{Float64,Float64}}()
        [push!(depotLocations,(loc[1],loc[2])) for loc in grid_centers]
        for gamma in GammaList
            for i in 1:nData
                println("n = ",nRequest," i = ",i)
                requestFile = string("Data/Konsentra/",nRequest,"/GeneratedRequests_",nRequest,"_",i,".csv")
                vehicleFile = string("Data/Konsentra/",nRequest,"/Vehicles_",nRequest,".csv")
                dataName = string("Data/Matrices/",nRequest,"/GeneratedRequests_",nRequest,"_",gamma,"_",i)
                
                getTimeDistanceMatrix(requestFile, depotLocations, dataName)
            end
        end
    end
end



#======================================================#
# # Find min and max lat and long
# #======================================================#
# maxLong = 0.0
# maxLat = 0.0
# minLong = typemax(Float64)
# minLat = typemax(Float64)
# for n in [20,100,300,500]
#     for i in 1:10 
#         fileName = string("Data/Konsentra/",n,"/GeneratedRequests_",n,"_",i,".csv")
#         requestsDf = CSV.read(fileName, DataFrame)

#         currentMaxLat = maximum(vcat(requestsDf.pickup_latitude,requestsDf.dropoff_latitude))
#         currentMinLat = minimum(vcat(requestsDf.pickup_latitude,requestsDf.dropoff_latitude))

#         currentMaxLong = maximum(vcat(requestsDf.pickup_longitude,requestsDf.dropoff_longitude))
#         currentMinLong = minimum(vcat(requestsDf.pickup_longitude,requestsDf.dropoff_longitude))

#         maxLat = max(maxLat,currentMaxLat)
#         maxLong = max(maxLong,currentMaxLong)
#         minLat = min(minLat,currentMinLat)
#         minLong = min(minLong,currentMinLong)
#     end
# end 

# println("Max Lat: ", maxLat)
# println("Min Lat: ", minLat)
# println("Max Long: ", maxLong)
# println("Min Long: ", minLong)
