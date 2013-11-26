#!/bin/bash
set -eux
###############################################################################
### PARAMS
VM=${1:-1}
VCORE=${2:-1}
DEPLOY=${3:-true}
###############################################################################
### ENV VAR
ENV_DEPLOY="wheezy-x64-nfs"

# Distem related variables
FSIMG="file:///home/ejeanvoine/public/distem/distem-fs-wheezy.tar.gz"
NODES="/root/DISTEM_NODES"
NET="/root/G5K_NET"
SSH_KEY='id_rsa'
IPFILE="/tmp/distem_vnodes_ip"
CPU_ALGO="hogs"
DISTEM_SETUP_FILE="/home/jemeras/public/distem/distem_tools/distem-setup.rb"
SHARED=true
#SHARED=false

# Charm++ related
CHARM_SOURCE="/home/jemeras/public/distem/distem_experiments/charm-6.5.1/"
CHARM_HOME='/root/charm-6.5.1'
CHARM_NODELIST="$CHARM_HOME/nodelist"
ARCH='net-linux-x86_64'
COMPILE_OPTIONS="-O3"

###############################################################################

if $DEPLOY; then
    katapult3 -e $ENV_DEPLOY -c
fi

SERVER=`cat $OAR_NODE_FILE | sort -u -V | head -1`
ssh root@$SERVER "distem --quit" || true ## ensure distem is dead

DISTEM_NODES_TMP=`mktemp`
G5K_NET_TMP=`mktemp`
cat $OAR_NODE_FILE | sort -u -V > $DISTEM_NODES_TMP
echo `g5k-subnets -sp` > $G5K_NET_TMP
taktuk -l root -f $DISTEM_NODES_TMP broadcast exec [ "echo \"Host *
StrictHostKeyChecking no
NoHostAuthenticationForLocalhost yes\" >> /root/.ssh/config" ]

### setup distem
if $SHARED; then
    DISTEM_BOOTSTRAP_OPT='--btrfs-format /dev/sda5'
else
    DISTEM_BOOTSTRAP_OPT=''
fi
distem-bootstrap -D -c $SERVER -f $DISTEM_NODES_TMP $DISTEM_BOOTSTRAP_OPT

scp $DISTEM_NODES_TMP root@$SERVER:$NODES
scp $G5K_NET_TMP root@$SERVER:$NET

if $SHARED; then
    DISTEM_SETUP_OPT='-s'
else
    DISTEM_SETUP_OPT=''
fi
ssh root@$SERVER "FSIMG=$FSIMG NODES=$NODES NET=$NET SSH_KEY=$SSH_KEY IPFILE=$IPFILE CPU_ALGO=$CPU_ALGO $DISTEM_SETUP_FILE -m $VM -c $VCORE $DISTEM_SETUP_OPT"

### build charm
ssh root@$SERVER "cp -r $CHARM_SOURCE $CHARM_HOME"
# Install compression packages needed by projections
ssh root@$SERVER "apt-get install -y --force-yes liblz-dev lib32z-dev"
# Install other usefull packages for NBP
ssh root@$SERVER "apt-get install -y --force-yes fortran77-compiler gfortran gfortran-multilib"
# compile charm
ssh root@$SERVER "cd $CHARM_HOME ; rm -rf $ARCH* ; ./build charm++ $ARCH $COMPILE_OPTIONS"
# compile stencil3D
ssh root@$SERVER "make projections -C $CHARM_HOME/$ARCH/examples/charm++/load_balancing/stencil3d/"
# compile liveViz and wave2d
ssh root@$SERVER "make clean -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/"
ssh root@$SERVER "make -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/"
ssh root@$SERVER "make -C $CHARM_HOME/$ARCH/examples/charm++/wave2d/"
# compile Mol2D
ssh root@$SERVER "make -C $CHARM_HOME/$ARCH/examples/charm++/Molecular2D/"

# create nodelist for charm and copy CHARM_HOME on vnodes
IPFILE_TMP=`mktemp` ; scp root@$SERVER:$IPFILE $IPFILE_TMP
CHARM_NODELIST_TMP=`mktemp`
echo 'group main' > $CHARM_NODELIST_TMP
for i in `cat $IPFILE_TMP`; do echo "host $i" >> $CHARM_NODELIST_TMP; done
scp $CHARM_NODELIST_TMP root@$SERVER:$CHARM_NODELIST
for i in `cat $IPFILE_TMP`; do ssh root@$i "rm -rf $CHARM_HOME"; done
for i in `cat $IPFILE_TMP`; do (scp -rp root@$SERVER:$CHARM_HOME root@$i:$CHARM_HOME &); done

### Connect the head node
ssh -X root@$SERVER
