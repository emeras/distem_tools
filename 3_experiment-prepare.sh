#!/bin/bash

set -eux

CHARM_SOURCE="/home/jemeras/public/distem/distem_experiments/charm-6.5.1/"
CHARM_HOME='/root/charm-6.5.1'

#### TO DO NEXT
# On COORDINATOR
# copy charm in local dir

# On Master
cp -r $CHARM_SOURCE $CHARM_HOME


apt-get install -y liblz-dev lib32z-dev
# compile charm
#cd $CHARM_HOME ; rm -rf net-linux-x86_64* ; ./build charm++ net-linux-x86_64 smp -O3
#cd $CHARM_HOME ; ln -s net-linux-x86_64-smp net-linux-x86_64
cd $CHARM_HOME ; rm -rf net-linux-x86_64* ; ./build charm++ net-linux-x86_64 -O3


# compile stencil3D
make projections -C $CHARM_HOME/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/

# compile liveViz and wave2d
make clean -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/
make -C $CHARM_HOME/tmp/libs/ck-libs/liveViz/
make -C $CHARM_HOME/net-linux-x86_64/examples/charm++/wave2d/

# compile Mol2D
make -C $CHARM_HOME/net-linux-x86_64/examples/charm++/Molecular2D/

# create nodelist
echo 'group main' > $CHARM_HOME/vnodeslist
for i in `cat /tmp/distem_vnodes_ip`; do echo "host $i" >> $CHARM_HOME/vnodeslist; done

# copy all on the nodes
for i in `cat /tmp/distem_vnodes_ip` ; do scp -rp $CHARM_HOME root@$i:$CHARM_HOME; done


