#!/bin/bash

################
#    change inputs here
################
n_requests_list=("20" "100" "300" "500")
anticipation_levels=("0.4")
run_tags=("run1" "run2" "run3" "run4" "run5")
gamma="0.7"
date="2025-05-28_original_0.7"
####################

mkdir -p submitfiles/generated_jobs

# Define case types
case_types=("InHindsight")

for case_type in "${case_types[@]}"; do
  for n_requests in "${n_requests_list[@]}"; do
    anticipation_loop=("0")  # default for BaseCase

    if [[ "$case_type" != "BaseCase" ]]; then
      anticipation_loop=("${anticipation_levels[@]}")
    fi

    for anticipation in "${anticipation_loop[@]}"; do
      for run_tag in "${run_tags[@]}"; do
        job_name="Sim_${case_type}_${n_requests}_${anticipation}_${run_tag}"
        job_file="submitfiles/generated_jobs/${job_name}.sh"

        if [[ "$case_type" == "BaseCase" ]]; then
          jl_file="resultExploration/resultsBase.jl"
          label="$case_type"
          anticipation="0"
        elif [[ "$case_type" == "Anticipation" ]]; then
          jl_file="resultExploration/resultsAnticipation.jl"
          label="${case_type}_${anticipation}"
        elif [[ "$case_type" == "AnticipationKeepExpected" ]]; then
          jl_file="resultExploration/resultsAnticipationKeepExpected.jl"
          label="${case_type}_${anticipation}"
        elif [[ "$case_type" == "InHindsight" ]]; then
          jl_file="resultExploration/resultsInHindsight.jl"
          label="${case_type}"
        else
          jl_file="resultExploration/resultsAnticipationNoALNS.jl"
          label="${case_type}_${anticipation}"
        fi

        cat > "$job_file" <<EOF
#!/bin/sh
#BSUB -J "${job_name}"
#BSUB -o submitfiles/output/output_%J.out
#BSUB -q hpc
#BSUB -n 8
#BSUB -R "rusage[mem=2GB] span[hosts=1]"
#BSUB -W 11:00
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
  julia --project=. $jl_file "$n_requests" "$anticipation" "$gamma" "$date" "$run_tag" "$label" "\$seed" &
done

wait
EOF

        chmod +x "$job_file"
        bsub < "$job_file"
      done
    done
  done
done
