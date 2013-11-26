#!/bin/bash
set -eux
###############################################################################
VM=$1
VCORE=$2

###############################################################################
CHARM_SOURCE="/home/jemeras/public/distem/distem_experiments/charm-6.5.1/"
CHARM_HOME='/root/charm-6.5.1'
###############################################################################

#oarsub -t deploy -l slash_22=1+cluster=1,nodes=4,walltime=8 'sleep 999999'
#katapult3 -e wheezy-x64-nfs -c


SERVER=`cat $OAR_NODEFILE | sort -u | head -1`
ssh root@$SERVER "distem --quit" ## ensure distem is dead

#distem-bootstrap -g -D --btrfs-format /dev/sda5 
distem-bootstrap

cat $OAR_NODEFILE | sort -u > DISTEM_NODES
echo `g5k-subnets -sp` > G5K_NET
taktuk -l root -f DISTEM_NODES broadcast exec [ "echo \"Host *
StrictHostKeyChecking no
NoHostAuthenticationForLocalhost yes\" >> /root/.ssh/config" ]
scp DISTEM_NODES root@$SERVER:; rm DISTEM_NODES 
scp G5K_NET root@$SERVER:; rm G5K_NET

# Now on Master
ssh root@$SERVER "cp -r $CHARM_SOURCE $CHARM_HOME"
ssh root@$SERVER "apt-get install -y --force-yes liblz-dev lib32z-dev"
# compile charm
ssh root@$SERVER "cd $CHARM_HOME ; rm -rf net-linux-x86_64* ; ./build charm++ net-linux-x86_64 -O3"
# compile stencil3D
ssh root@$SERVER "make projections -C $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/"
# compile liveViz and wave2d
ssh root@$SERVER "make clean -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/"
ssh root@$SERVER "make -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/"
ssh root@$SERVER "make -C $CHARM_HOME/net-linux-x86_64/examples/charm++/wave2d/"
# compile Mol2D
ssh root@$SERVER "make -C $CHARM_HOME/net-linux-x86_64/examples/charm++/Molecular2D/"

# copy all on the nodes
ssh root@$SERVER "for i in `cat /root/DISTEM_NODES` ; do scp -rp $CHARM_HOME root@$i:$CHARM_HOME; done"

# setup distem
ssh root@$SERVER "~jemeras/public/distem/distem_tools/distem-setup.rb -v $VM -c $VCORE"

# create nodelist for charm
ssh root@$SERVER "echo 'group main' > $CHARM_HOME/vnodeslist"
ssh root@$SERVER "for i in `cat /tmp/distem_vnodes_ip`; do echo "host $i" >> $CHARM_HOME/vnodeslist; done"

# Connect the head node
ssh -X root@$SERVER
