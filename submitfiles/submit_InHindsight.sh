#!/bin/bash

# Constants

# OBS OBS OBS 
gamma=0.5
# OBS OBS OBS 

gridSize=10

nRequestsList=(300 500) 
numRuns=5
numData=10  
baseScenario="true"

mkdir -p submitfiles/generated_jobs
for nRequests in "${nRequestsList[@]}"; do
        for run in $(seq 1 $numRuns); do
            job_name="Sim_Waiting_${nRequests}_inhindsight_${run}"
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

for i in \$(seq 1 ${numData}); do
    julia --project=. runfiles/RunInHindSight.jl "${nRequests}" "${gamma}" "\${i}" "${gridSize}" "${run}" "${baseScenario}" &
done

wait
EOF

            chmod +x "$job_file"
            bsub < "$job_file"
        done
    done
done
