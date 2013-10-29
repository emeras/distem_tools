#!/bin/bash

#oarsub -t deploy -l slash_22=1+nodes=4,walltime=8 'katapult3 -e wheezy-x64-nfs -c --sleep'

#katapult3 -e wheezy-x64-nfs -c


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


ssh root@$SERVER "~jemeras/public/distem/distem_tools/setup_test.rb"

ssh root@$SERVER


exit 0


#### TO DO NEXT
# On COORDINATOR
apt-get install -y liblz-dev lib32z-dev

cp -r ~jemeras/public/distem/distem_experiments/charm-6.5.1 .

cd charm-6.5.1/ ; ./build charm++ net-linux-x86_64 -O3

cd net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; make clean ; make ; make projections'




