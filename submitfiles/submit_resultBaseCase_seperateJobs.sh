#!/bin/bash

n_requests_list=("300" "500")
run_tags=("run1")
gamma="0.5"
date="2025-05-20_2"
mkdir -p submitfiles/generated_jobs

for n_requests in "${n_requests_list[@]}"; do
    for run_tag in "${run_tags[@]}"; do
        for seed in {1..10}; do
            job_name="Sim_BaseCase_${n_requests}_${run_tag}_seed${seed}"
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

julia --project=. resultExploration/resultsBase.jl "$n_requests" "0" "$gamma" "$date" "$run_tag" "BaseCase" "$seed"
EOF

            # Make it executable
            chmod +x "$job_file"

            # Submit the job
            bsub < "$job_file"
        done
    done
done
