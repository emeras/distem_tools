#!/bin/bash

CHARM_HOME='/root/charm-6.5.1'

# On COORDINATOR
NBNODES=`cat /root/DISTEM_NODES | wc -l`
NBCORES=`nproc`
TOTAL_CORES=$(($NBNODES * $NBCORES))

#STENCIL_PARAMS='1024 32'
STENCIL_PARAMS='8192 8192 1 256 256 1'

STENCIL_OPTS=$STENCIL_PARAMS #' +balancer RefineLB'
#STENCIL_OPTS=$STENCIL_PARAMS' +LBOff'

# Erase potential older results
for i in `cat /tmp/distem_vnodes_ip` ; do ssh root@$i "rm -f $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.*"; done

# DO THIS ON FIRST VNODE
ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./stencil3d.prj $STENCIL_OPTS +LBOff"

# grab results
DIR=expe_`date +%s`_LBOff
mkdir $DIR
for i in `cat /tmp/distem_vnodes_ip` ; do scp -rp root@$i:$CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.* ./$DIR; done





for i in `cat /tmp/distem_vnodes_ip` ; do ssh root@$i "rm -f $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.*"; done

# DO THIS ON FIRST VNODE
ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./stencil3d.prj $STENCIL_OPTS +balancer GreedyLB"

# grab results
DIR=expe_`date +%s`_GreedyLB
mkdir $DIR
for i in `cat /tmp/distem_vnodes_ip` ; do scp -rp root@$i:$CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.* ./$DIR; done





for i in `cat /tmp/distem_vnodes_ip` ; do ssh root@$i "rm -f $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.*"; done

# DO THIS ON FIRST VNODE
ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./stencil3d.prj $STENCIL_OPTS +balancer RefineLB"

# grab results
DIR=expe_`date +%s`_RefineLB
mkdir $DIR
for i in `cat /tmp/distem_vnodes_ip` ; do scp -rp root@$i:$CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.* ./$DIR; done










exit 0 # continue manually

# MAKE A NODE SLOWER
distem --get-vnode-info
NODE='...'
distem --config-vcpu vnode=$NODE,cpu_speed=0.5  #"1000 MHz"
# THEN REPLAY SAME AS ABOVE

# THEN TRY WITH NO LB


# OPTIONS FOR STENCIL: LB
# +LBOff 
# +balancer <name of LB>   GreedyLB RefineLB RefineSwapLB
# +LBPeriod <period in sec.>
# +LBPredictor 
# 


