#!/bin/bash

# oarsub -t deploy -l slash_22=1+nodes=4,walltime=8 'sleep 999999'
# kadeploy3 -f $OAR_NODE_FILE -e wheezy-x64-nfs -k

#katapult3 -e wheezy-x64-nfs -c --sleep # -- sleep 999999


SERVER=`cat $OAR_NODEFILE | sort -u | head -1`

ssh root@$SERVER "distem --quit"

distem-bootstrap -g -D --btrfs-format /dev/sda5 
#distem-bootstrap

cat $OAR_NODEFILE | sort -u > DISTEM_NODES
echo `g5k-subnets -sp` > G5K_NET

taktuk -l root -f DISTEM_NODES broadcast exec [ "echo \"Host *
StrictHostKeyChecking no
NoHostAuthenticationForLocalhost yes\" >> /root/.ssh/config" ]

scp DISTEM_NODES root@$SERVER:; rm DISTEM_NODES 
scp G5K_NET root@$SERVER:; rm G5K_NET


ssh root@$SERVER "~jemeras/distem_tools/setup_test.rb"

ssh root@$SERVER

