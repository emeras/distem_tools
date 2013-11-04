#!/bin/bash

CHARM_HOME='/root/charm-6.5.1'

# On COORDINATOR
NBNODES=`cat /root/DISTEM_NODES | wc -l`
NBCORES=`nproc`
TOTAL_CORES=$(($NBNODES * $NBCORES))

STENCIL_PARAMS='1024 32'
#STENCIL_PARAMS='8192 8192 1 256 256 1'

# DO THIS ON FIRST VNODE
ssh root@`cat /tmp/distem_nodes_ip_* | head -1` "cd $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/vnodeslist ./stencil3d.prj $STENCIL_PARAMS"

# grab results
for i in `cat /tmp/distem_nodes_ip_*` ; do scp -rp root@$i:$CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.* .; done
DIR=expe_`date +%s`
mkdir $DIR
mv ./stencil3d.prj.* $DIR


exit 0 # continue manually

# MAKE A NODE SLOWER
distem --get-vnode-info
NODE='...'
distem --config-vcpu vnode=$NODE,cpu_speed="1000 MHz"
# THEN REPLAY SAME AS ABOVE

# THEN TRY WITH NO LB


# OPTIONS FOR STENCIL: LB
# +LBOff 
# +balancer <name of LB>   GreedyLB RefineLB RefineSwapLB
# +LBPeriod <period in sec.>
# +LBPredictor 
# 


