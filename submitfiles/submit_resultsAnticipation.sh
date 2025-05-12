#!/bin/sh
#BSUB -J "Simulate_scenario"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 10:00
#BSUB -u s194351@student.dtu.dk
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
Pkg.resolve();
'

# Loop to run simulations with third argument from 1 to 10
for i in {1..10}; do
    julia --project=. resultExploration/resultsAnticipation.jl "500" "0.1" "0.5" "12-05-2025" "BasicAnticipation" "$i" &
done

wait  # Wait for all background Julia jobs to finish