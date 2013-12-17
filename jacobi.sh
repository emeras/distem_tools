#!/bin/bash

CHARM_HOME='/root/charm-6.5.1'
#TOTAL_CORES=$1
TOTAL_CORES=1024
JACOBI_PARAMS="2048 32"
EXPE_RUN_TIME=1200

nohup ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64-syncft/tests/charm++/jacobi3d ; ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./jacobi3d $JACOBI_PARAMS" > ./jacobi.log &

# failures
~jemeras/public/distem/distem_tools/churn_node.rb all $EXPE_RUN_TIME &

# grab results
# DIR=expe_`date +%s`
# mkdir $DIR
# for i in `cat /tmp/distem_vnodes_ip` ; do scp -rp root@$i:$CHARM_HOME/net-linux-x86_64-syncft/tests/charm++/jacobi3d/jacobi3d.prj.* ./$DIR; done
