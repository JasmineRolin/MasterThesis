#!/bin/bash

n_requests_list=("20" "100" "300" "500")
anticipation_levels=("0.5" "0.9")
run_tags=("run1" "run2" "run3" "run4" "run5")
gamma="0.7"
date="2025-05-15"

mkdir -p submitfiles/generated_jobs

for n_requests in "${n_requests_list[@]}"; do
  for anticipation in "${anticipation_levels[@]}"; do
    for run_tag in "${run_tags[@]}"; do
      job_name="Sim_AnticipationNoALNS_${n_requests}_${anticipation}_${run_tag}"
      job_file="submitfiles/generated_jobs/${job_name}.sh"

      cat > "$job_file" <<EOF
#!/bin/sh
#BSUB -J "${job_name}"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB]"
#BSUB -R "span[hosts=1]"
#BSUB -W 10:00
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
  julia --project=. resultExploration/resultsAnticipationNoALNS.jl "$n_requests" "$anticipation" "$gamma" "$date" "$run_tag" "AnticipationNoALNS_${anticipation}" "\$seed" &
done

wait
EOF

      # Make it executable
      chmod +x "$job_file"

      # Optionally submit the job right away
      bsub < "$job_file"
    done
  done
done
