#!/bin/bash

# TODO: change i and endfile!!!

gamma=0.7
nPeriods=48
gridSize=10

nRequestsList=(300) 
relocateOptions=(true false)
numRuns=3  
numSteps=20   

mkdir -p submitfiles/generated_jobs
for nRequests in "${nRequestsList[@]}"; do
    for relocateVehicles in "${relocateOptions[@]}"; do
            for run in $(seq 1 $numRuns); do
                job_name="Sim_Waiting_${nRequests}_${relocateVehicles}_${run}"
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

for i in \$(seq 1 ${numSteps}); do
    endFile=\$((1 + 19))
    julia --project=. runfiles/RunSimulationWaiting.jl "${nRequests}" "${gamma}" "\${i}" "${relocateVehicles}" "${gridSize}" "1" "\${endFile}" "${nPeriods}" "${run}" &
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
