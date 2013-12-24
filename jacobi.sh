#!/bin/bash

### EXPE SETUP:
### griffon 32 nodes, 8vm per node, 1 vcore per vm


CHARM_HOME='/root/charm-6.5.1'
#TOTAL_CORES=$1
#TOTAL_CORES=1024
TOTAL_CORES=256
JACOBI_PARAMS="2048 2048 1024 256 256 256"
#JACOBI_PARAMS="8192 8192 1 512 512 1"
CHURN_DURATION=1200
SEC_TIME=300

taktuk -s -f /tmp/distem_vnodes_ip_hostnames broadcast exec [ hostname ]

LOGFILE="jacobi_`date +%s`.log"


# No FT
nohup ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64/tests/charm++/jacobi3d ; time ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./jacobi3d $JACOBI_PARAMS" > "$LOGFILE.noFT" &
wait
cp "$LOGFILE.noFT" ~jemeras/public/

# FT but no Failures
nohup ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64-syncft/tests/charm++/jacobi3d ; time ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./jacobi3d $JACOBI_PARAMS" > "$LOGFILE.FT_noFail" &
wait
cp "$LOGFILE.FT_noFail" ~jemeras/public/

for i in 24 12 6 3 1; do
nohup ssh root@`cat /tmp/distem_vnodes_ip | head -1` "cd $CHARM_HOME/net-linux-x86_64-syncft/tests/charm++/jacobi3d ; time ./charmrun ++p $TOTAL_CORES ++nodelist $CHARM_HOME/nodelist ./jacobi3d $JACOBI_PARAMS" > "$LOGFILE.FT_$i" &
# security time to wait the experiment start
sleep $SEC_TIME
# failures
ruby ~jemeras/public/distem/distem_tools/churn_node.rb all $CHURN_DURATION $i
wait
# grab results
cp "$LOGFILE.FT_$i" ~jemeras/public/
done
