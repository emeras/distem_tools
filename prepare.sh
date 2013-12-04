#!/bin/bash
set -ex
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
DISTEM_BOOTSTRAP="/home/ejeanvoine/distem-bootstrap"
NODES="/root/DISTEM_NODES"
NET="/root/G5K_NET"
SSH_KEY='id_rsa'
IPFILE="/tmp/distem_vnodes_ip"
CPU_ALGO="hogs"
DISTEM_SETUP_FILE="/home/jemeras/public/distem/distem_tools/distem-setup.rb"
SHARED=true
if [ "$CHECKPOINT" == ""  ]; then
    CHECKPOINT=false
fi
# SMP=false

# Charm++ related
CHARM_SOURCE="/home/jemeras/public/distem/distem_experiments/charm-6.5.1/"
CHARM_HOME='/root/charm-6.5.1'
CHARM_NODELIST="$CHARM_HOME/nodelist"
BUILD='net-linux-x86_64'
BUILD_PATH=$BUILD
COMPILE_OPTIONS=''  #-DCK_NO_PROC_POOL=1
BUILD_ALL_OPTIONS=''

# # SMP option is taken before syncft in the build path
# if $SMP; then
#     OPTION='smp'
#     BUILD_ALL_OPTIONS=$BUILD_ALL_OPTIONS' '$OPTION
#     BUILD_PATH=$BUILD_PATH-$OPTION
# fi

if $CHECKPOINT; then
    OPTION='syncft'
    BUILD_ALL_OPTIONS=$BUILD_ALL_OPTIONS' '$OPTION
    BUILD_PATH=$BUILD_PATH-$OPTION
    COMPILE_OPTIONS=$COMPILE_OPTIONS" -O0" # set optimization level to 0, O3 does not work for FT...
else
    COMPILE_OPTIONS=$COMPILE_OPTIONS" -O3"
fi

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
ssh root@$SERVER "FSIMG=$FSIMG NODES=$NODES NET=$NET SSH_KEY=$SSH_KEY IPFILE=$IPFILE CPU_ALGO=$CPU_ALGO $DISTEM_SETUP_FILE -m $VM -c $VCORE $DISTEM_SETUP_OPT"

### build charm
ssh root@$SERVER "rm -rf $CHARM_HOME"
ssh root@$SERVER "cp -r $CHARM_SOURCE $CHARM_HOME"
# Install compression packages needed by projections
ssh root@$SERVER "apt-get install -y --force-yes liblz-dev lib32z-dev"
# Install other usefull packages for NBP
ssh root@$SERVER "apt-get install -y --force-yes fortran77-compiler gfortran gfortran-multilib"
# compile charm
ssh root@$SERVER "cd $CHARM_HOME ; rm -rf $BUILD* ; ./build charm++ $BUILD $BUILD_ALL_OPTIONS $COMPILE_OPTIONS"
# compile stencil3D
ssh root@$SERVER "make -C $CHARM_HOME/$BUILD_PATH/examples/charm++/load_balancing/stencil3d/"
ssh root@$SERVER "make projections -C $CHARM_HOME/$BUILD_PATH/examples/charm++/load_balancing/stencil3d/"
# compile liveViz and wave2d
ssh root@$SERVER "make clean -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/"
ssh root@$SERVER "make -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/"
ssh root@$SERVER "make -C $CHARM_HOME/$BUILD_PATH/examples/charm++/wave2d/"
# compile Mol2D
ssh root@$SERVER "make -C $CHARM_HOME/$BUILD_PATH/examples/charm++/Molecular2D/"
# compile stencil with checkpoint enabled (jacobi)
ssh root@$SERVER "make -C $CHARM_HOME/$BUILD_PATH/tests/charm++/jacobi3d"
ssh root@$SERVER "make projections -C $CHARM_HOME/$BUILD_PATH/tests/charm++/jacobi3d"


# create nodelist for charm and copy CHARM_HOME on vnodes
IPFILE_TMP=`mktemp` ; scp root@$SERVER:$IPFILE $IPFILE_TMP
CHARM_NODELIST_TMP=`mktemp`
echo 'group main' > $CHARM_NODELIST_TMP
for i in `cat $IPFILE_TMP`; do echo "host $i" >> $CHARM_NODELIST_TMP; done
scp $CHARM_NODELIST_TMP root@$SERVER:$CHARM_NODELIST

if $SHARED; then
    for i in `cat $DISTEM_NODES_TMP`; do ssh root@$i "rm -rf /tmp/distem/rootfs-shared/*/$CHARM_HOME"; done
    for i in `cat $DISTEM_NODES_TMP`; do scp -rp root@$SERVER:$CHARM_HOME root@$i:/tmp/distem/rootfs-shared/*`dirname $CHARM_HOME`; done  
else
    for i in `cat $IPFILE_TMP`; do ssh root@$i "rm -rf $CHARM_HOME"; done
    for i in `cat $IPFILE_TMP`; do scp -rp root@$SERVER:$CHARM_HOME root@$i:$CHARM_HOME; done
fi

### Connect the head node
ssh -X root@$SERVER
