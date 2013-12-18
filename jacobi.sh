#!/bin/bash

CHARM_HOME='/root/charm-6.5.1'
#TOTAL_CORES=$1
TOTAL_CORES=1024
JACOBI_PARAMS="2048 32"
CHURN_DURATION=2000
SEC_TIME=600

taktuk -s -f /tmp/distem_vnodes_ip_hostnames broadcast exec [ hostname ]

nohup ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64-syncft/tests/charm++/jacobi3d ; time ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./jacobi3d $JACOBI_PARAMS" > ./jacobi.log &

# security time to wait the experiment start
sleep $SEC_TIME
# failures
~jemeras/public/distem/distem_tools/churn_node.rb all $CHURN_DURATION &

# grab results
# DIR=expe_`date +%s`
# mkdir $DIR
# for i in `cat /tmp/distem_vnodes_ip` ; do scp -rp root@$i:$CHARM_HOME/net-linux-x86_64-syncft/tests/charm++/jacobi3d/jacobi3d.prj.* ./$DIR; done
