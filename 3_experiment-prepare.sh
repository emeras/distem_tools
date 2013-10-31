#!/bin/bash

#### TO DO NEXT
# On COORDINATOR

# install libz
for i in `cat /root/DISTEM_NODES`; do apt-get install -y liblz-dev lib32z-dev; done

# copy charm in local dir
cp -r ~jemeras/public/distem/distem_experiments/charm-6.5.1 .

# compile charm
#cd charm-6.5.1/ ; rm -rf net-linux-x86_64 ; ./build charm++ net-linux-x86_64 -O3
cd charm-6.5.1/ ; rm -rf net-linux-x86_64 ; ./build charm++ net-linux-x86_64 smp -O3

# and stencil
cd net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; make clean ; make ; make projections


# create nodelist
echo 'group main' > ./vnodeslist
cat /tmp/distem_nodes_ip_* >> ./vnodeslist_tmp
for i in `cat ./vnodeslist_tmp`; do echo "host $i" >> ./vnodeslist; done
rm ./vnodeslist_tmp

for i in `cat /tmp/distem_nodes_ip_*` ; do scp -rp /root/charm-6.5.1/ root@$i:; done

NBNODES=`cat /root/DISTEM_NODES | wc -l`
NBCORES=`nproc`
TOTAL_CORES=$(($NBNODES * $NBCORES))

# DO THIS ON FIRST VNODE
ssh root@`cat /tmp/distem_nodes_ip_* | head -1` "cd /root/charm-6.5.1/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; ./charmrun ++p $TOTAL_CORES ++nodelist ./vnodeslist ./stencil3d.prj 8192 8192 1 256 256 1"

# grab results
for i in `cat /tmp/distem_nodes_ip_*` ; do scp -rp root@$i:/root/charm-6.5.1/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil3d.prj.* .; done

# SAVE RESULTS
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


