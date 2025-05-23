#!/bin/sh
#BSUB -J "Sim_Ant_300_0.4_run2_seed4"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 5:00
#BSUB -u s194321@student.dtu.dk
#BSUB -N 

module load julia/1.10.2

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

julia --project=. resultExploration/resultsAnticipation.jl "300" "0.4" "0.5" "2025-05-22_expCost100" "run2" "Anticipation_0.4" "4"
