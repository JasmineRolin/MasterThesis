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

# Loop to run simulations with third argument from 1 to 10
# OBS: update grid size!!
#r i in {1..81..20}; do
    i=$((1))
    endFile=$((i + 19))
    julia --project=. runfiles/RunSimulationWaiting.jl "300" "0.7" "$i" "false" "10" "$i" "$endFile" "48" &
#done

wait  # Wait for all background Julia jobs to finish