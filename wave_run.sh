#!/bin/bash

CHARM_HOME='/root/charm-6.5.1'

# On COORDINATOR
NBNODES=`cat /root/DISTEM_NODES | wc -l`
NBCORES=`nproc`
TOTAL_CORES=$(($NBNODES * $NBCORES))

WAVE_PARAMS='12288 12288'

# DO THIS ON FIRST VNODE
ssh root@`cat /tmp/distem_nodes_ip_* | head -1` "cd $CHARM_HOME/net-linux-x86_64/examples/charm++/wave2d ; ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/vnodeslist ./wave2d $WAVE_PARAMS"

# TODO: grab results


