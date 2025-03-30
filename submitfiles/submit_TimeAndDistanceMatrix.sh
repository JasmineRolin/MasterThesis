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

julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_1.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_1"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_2.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_2"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_3.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_3"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_4.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_4"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_5.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_5"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_6.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_6"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_7.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_7"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_8.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_8"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_9.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_9"
julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/500/GeneratedRequests_500_10.csv" "Data/Konsentra/500/Vehicles_500.csv" "Data/Matrices/500/GeneratedRequests_500_10"

