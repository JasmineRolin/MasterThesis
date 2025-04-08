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

# load Julia version
module load julia/1.10.2

# Activate project 
julia -e 'using Pkg; Pkg.activate("."), Pkg.add("DataFrames"); Pkg.add("CSV"),Pkg.develop(path="domain"); Pkg.develop(path="utils");Pkg.develop(path="offlinesolution");Pkg.develop(path="onlinesolution");Pkg.develop(path="alns");Pkg.develop(path="simulationframework");'

julia tests/SimulationFrameworkTest.jl "500"

