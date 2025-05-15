#!/bin/sh
#BSUB -J "Simulate_scenario"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 10:00
#BSUB -u s194321@student.dtu.dk
#BSUB -N 
# end of BSUB options

# Load Julia module
module load julia/1.10.2

# Activate project and install dependencies
julia --project=. -e '
using Pkg;
Pkg.activate(".");
Pkg.add("Plots");
Pkg.add("DataFrames");
Pkg.add("CSV");
Pkg.develop(path="domain");
Pkg.develop(path="utils");
Pkg.develop(path="offlinesolution");
Pkg.develop(path="onlinesolution");
Pkg.develop(path="alns");
Pkg.develop(path="simulationframework");
Pkg.develop(path="waitingstrategies");
Pkg.resolve();
'

#
#        !!!# OBS OBS OBS OBS OBS #!!!!!
#
#        To run the scenarios with short call time (in Data/WaitingStrategies)
#        - change MAX_DELAY = 15 and MAX_EARLY_ARRIVAL = 5 in instance reader 
#        - outcomment check for buffer in instance reader in readRequests
#                if callTime > requestTime - bufferTime
#                    throw(ArgumentError(string("Call time is not before required buffer period for request: ",id)))
#                end
#


# OBS: update grid size!!
gridSize=10
nRequests=500
relocateVehicles=false

# Loop to run simulation
for i in {1..81..20}; do
    endFile=$((i + 19))
    julia --project=. runfiles/RunSimulationWaiting.jl "$nRequests" "0.7" "$i" "$relocateVehicles" "$gridSize" "$i" "$endFile" "48" &
done


wait  # Wait for all background Julia jobs to finish