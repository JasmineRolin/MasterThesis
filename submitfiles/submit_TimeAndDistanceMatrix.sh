#!/bin/sh
#BSUB -J "Distance_and_Matrix_file"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 10:00
#BSUB -u s194351@student.dtu.dk
#BSUB -N 
# end of BSUB options

# load Julia version
module load julia/1.10.2

# Activate project 
julia -e 'using Pkg; Pkg.activate("."), Pkg.add("DataFrames"); Pkg.add("CSV"),Pkg.develop(path="domain"); Pkg.develop(path="utils");Pkg.develop(path="offlinesolution");Pkg.develop(path="onlinesolution");Pkg.develop(path="alns");Pkg.develop(path="simulationframework");'

julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_1.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_1"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_2.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_2"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_3.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_3"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_4.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_4"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_5.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_5"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_6.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_6"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_7.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_7"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_8.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_8"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_9.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_9"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/20/GeneratedRequests_20_10.csv" "Data/Konsentra/20/Vehicles_20.csv" "Data/Matrices/20/GeneratedRequests_20_10"

