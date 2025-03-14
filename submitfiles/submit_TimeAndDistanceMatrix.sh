#!/bin/sh
#BSUB -J test
#BSUB -o output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 1:00
#BSUB -u s194351@student.dtu.dk
#BSUB -N 
# end of BSUB options

# load Julia version
module load julia/1.10.2

julia dataexploration/MakeAndSaveDistanceAndTimeMatrix.jl "Data/Konsentra/TransformedData_Data.csv" "Data/Konsentra/Vehicles.csv" "Konsentra_newVehicles"
