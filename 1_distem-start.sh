#!/bin/bash

#oarsub -t deploy -l slash_22=1+cluster=1,nodes=4,walltime=8 'katapult3 -e wheezy-x64-nfs -c --sleep'

#katapult3 -e wheezy-x64-nfs -c


SERVER=`cat $OAR_NODEFILE | sort -u | head -1`

ssh root@$SERVER "distem --quit"

#distem-bootstrap -g -D --btrfs-format /dev/sda5 
distem-bootstrap

cat $OAR_NODEFILE | sort -u > DISTEM_NODES
echo `g5k-subnets -sp` > G5K_NET

taktuk -l root -f DISTEM_NODES broadcast exec [ "echo \"Host *
StrictHostKeyChecking no
NoHostAuthenticationForLocalhost yes\" >> /root/.ssh/config" ]

scp DISTEM_NODES root@$SERVER:; rm DISTEM_NODES 
scp G5K_NET root@$SERVER:; rm G5K_NET

exit 0
# ssh root@$SERVER "~jemeras/public/distem/distem_tools/2_distem-setup.rb"
# ssh root@$SERVER "~jemeras/public/distem/distem_tools/3_experiment-prepare.sh"
# 
# ssh -X root@$SERVER

