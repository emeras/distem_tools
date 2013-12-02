### How to prepare a Charm++ experiment on G5K.

# Connect the platform, then nancy site (scripts and images are there)
ssh access.grid5000.fr -l <G5K_USER_NAME>
ssh nancy

# If not already done generate ssh keys for nopasswd access between nodes
ssh-keygen -t rsa
cat .ssh/id_rsa.pub >> .ssh/authorized_keys

# Reserve some nodes, with this command you have 4 nodes for 4 hours
JOB=`oarsub -t deploy -l slash_22=1+nodes=4,walltime="04:00:00" 'sleep 99999999' 2>&1 | awk -F 'OAR_JOB_ID=' '{print $2}' | tail -n 1`

# Wait for the job to be running (State = R)
oarstat -j $JOB

# Then, connect to the job
oarsub -C $JOB

# Prepare experiment, first parameter is number of vnodes (virtual nodes) per host, second is vcore per vnode.
~jemeras/public/distem/distem_tools/prepare.sh 4 1

# Run experiment (e.g., stencil)
~jemeras/public/distem/distem_tools/stencil_run.sh <TOTAL_NB_CORES>