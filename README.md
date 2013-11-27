
# First Reserve Nodes
oarsub -t deploy -l slash_22=1+nodes=3,walltime=2 'sleep 9999999'

# Connect Job
oarsub -C 493496

# Prepare experiment, first param is number of virtual nodes per host, second is vcore per vnode, third is re-deploy or not
~jemeras/public/distem/distem_tools/prepare.sh 4 1 true/false

# Run Expe
~jemeras/public/distem/distem_tools/stencil_run.sh <TOTAL_NB_CORES>