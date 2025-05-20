#!/bin/bash

n_requests_list=("300" "500")
anticipation_levels=("0.4")
run_tags=("run1" "run2")
gamma="0.5"
date="2025-05-20"

mkdir -p submitfiles/generated_jobs

for n_requests in "${n_requests_list[@]}"; do
  for anticipation in "${anticipation_levels[@]}"; do
    for run_tag in "${run_tags[@]}"; do
      for seed in {1..10}; do
        job_name="Sim_Ant_${n_requests}_${anticipation}_${run_tag}_seed${seed}"
        job_file="submitfiles/generated_jobs/${job_name}.sh"

        cat > "$job_file" <<EOF
#!/bin/sh
#BSUB -J "${job_name}"
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

julia --project=. resultExploration/resultsAnticipation.jl "$n_requests" "$anticipation" "$gamma" "$date" "$run_tag" "Anticipation_${anticipation}" "$seed"
EOF

        chmod +x "$job_file"
        bsub < "$job_file"
      done
    done
  done
done
