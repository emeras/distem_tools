#!/bin/bash
set -ex
###############################################################################
### PARAMS
VM=${1:-100}
VCORE=${2:-0}
DEPLOY=${3:-true}
###############################################################################
### ENV VAR
ENV_DEPLOY="wheezy-x64-nfs"

# Distem related variables
FSIMG="file:///home/ejeanvoine/public/distem/distem-fs-wheezy.tar.gz"
DISTEM_BOOTSTRAP="/home/ejeanvoine/distem-bootstrap"
NODES="/root/DISTEM_NODES"
NET="/root/G5K_NET"
SSH_KEY='id_rsa'
IPFILE="/tmp/distem_vnodes_ip"
CPU_ALGO="hogs"
DISTEM_SETUP_FILE="/home/jemeras/public/distem/distem_tools/distem-setup_dev.rb"
MPI_COLLECTIVE_FILE_PATH="~jemeras/public/distem/distem_tools"
SHARED=true
#AUTO=true
AUTO=false
###############################################################################

#echo '' > ~/.ssh/known_hosts
NODES_TO_DEPLOY=`cat $OAR_NODE_FILE | sort -u -V | wc -l`
if $DEPLOY; then
    katapult3 -e $ENV_DEPLOY -c --min-deployed-nodes $NODES_TO_DEPLOY
fi

SERVER=`cat $OAR_NODE_FILE | sort -u -V | head -1`
#ssh root@$SERVER "distem --quit" || true ## ensure distem is dead

DISTEM_NODES_TMP=`mktemp`
G5K_NET_TMP=`mktemp`
cat $OAR_NODE_FILE | sort -u -V > $DISTEM_NODES_TMP
echo `g5k-subnets -sp` > $G5K_NET_TMP
taktuk -l root -f $DISTEM_NODES_TMP broadcast exec [ "echo \"Host *
StrictHostKeyChecking no
NoHostAuthenticationForLocalhost yes\" >> /root/.ssh/config" ]

### setup distem

# If we do not use shared images we need to use a btrfs partition to host the root image.
if $SHARED; then
    DISTEM_BOOTSTRAP_OPT=''
else
    DISTEM_BOOTSTRAP_OPT='--btrfs-format /dev/sda5'
fi
$DISTEM_BOOTSTRAP -D -c $SERVER -f $DISTEM_NODES_TMP $DISTEM_BOOTSTRAP_OPT -g --max-vifaces $VM

scp $DISTEM_NODES_TMP root@$SERVER:$NODES
scp $G5K_NET_TMP root@$SERVER:$NET

if $SHARED; then
    DISTEM_SETUP_OPT='-s'
else
    DISTEM_SETUP_OPT=''
fi
if $AUTO; then
    DISTEM_SETUP_OPT=$DISTEM_SETUP_OPT' -a'
fi
ssh root@$SERVER "FSIMG=$FSIMG NODES=$NODES NET=$NET SSH_KEY=$SSH_KEY IPFILE=$IPFILE CPU_ALGO=$CPU_ALGO $DISTEM_SETUP_FILE -m $VM -c $VCORE $DISTEM_SETUP_OPT"

NBNODES=`cat $DISTEM_NODES_TMP | wc -l`
NBVMTOT=$(($NBNODES * $VM))

ssh root@$SERVER "cp $MPI_COLLECTIVE_FILE_PATH/collective_ops*.c /root/"
ssh root@$SERVER "cd /root/ ; mpicc -O3 collective_ops.c -o collective_ops"
#ssh root@$SERVER "cd /root/ ; mpicc -O3 collective_ops_reduce.c -o collective_ops_reduce"
#ssh root@$SERVER "cd /root/ ; mpicc -O3 collective_ops_barrier.c -o collective_ops_barrier"

#ssh root@$SERVER "taktuk -s -f $IPFILE broadcast put [ /root/collective_ops ] [ /root/collective_ops ]"
ssh root@$SERVER "while read i; do scp -p collective_ops* \$i:/tmp/distem/rootfs-shared/*/root; done < $NODES"
ssh root@$SERVER "while read i; do scp -p $IPFILE \$i:/tmp/distem/rootfs-shared/*/root; done < $NODES"
ssh root@$SERVER "taktuk -s -f $IPFILE broadcast exec [ hostname ]"


# Then run mpi
# ssh root@$SERVER "rm run_times.log || true"
# ssh root@$SERVER "for i in {1..10}; do /usr/bin/time -f %e --output=run_times.log --append mpirun -machinefile $IPFILE --mca btl tcp,self ./collective_ops; done"
# ssh root@$SERVER "cp /root/run_times.log ~jemeras/public/run_times.log.$NBVMTOT.`date +%s`"
LOGFILE="/home/jemeras/public/scalability.`date +%s`"
echo 'Running MPI'
ssh root@$SERVER "for t in {1..100}; do for i in 100 500 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000; do head -n \$i $IPFILE > out; /usr/bin/time -f %e --output=$LOGFILE".\$i.total" --append mpirun --mca btl tcp,self -machinefile out /root/collective_ops >> $LOGFILE".\$i.loop" ; done ; done"
echo 'Done'




#### THEN: on ~jemeras/public dir, aggregate results
# for i in 100 500 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000; do cat *.$i.loop >> $i'_loop'; cat *.$i.total >> $i'_total'; done
