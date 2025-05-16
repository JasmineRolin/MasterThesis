#!/bin/sh
#BSUB -J "Sim_Anticipation_100_0.3_run3"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 5:00
#BSUB -u s194351@student.dtu.dk
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

for seed in {1..10}; do
  julia --project=. resultExploration/resultsAnticipation.jl "100" "0.3" "0.7" "2025-05-16" "run3" "Anticipation_0.3" "$seed" &
done

wait
