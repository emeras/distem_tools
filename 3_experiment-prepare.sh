#!/bin/bash

#### TO DO NEXT
# On COORDINATOR

# install libz
for i in `cat /root/DISTEM_NODES`; do apt-get install -y liblz-dev lib32z-dev; done

# copy charm in local dir
cp -r ~jemeras/public/distem/distem_experiments/charm-6.5.1 .

# compile charm
cd charm-6.5.1/ ; rm -rf net-linux-x86_64 ; ./build charm++ net-linux-x86_64 -O3
# and stencil
cd net-linux-x86_64/examples/charm++/load_balancing/stencil3d/ ; make clean ; make ; make projections


# create nodelist
echo 'group main' > ./vnodeslist
cat /tmp/distem_nodes_ip_* >> ./vnodeslist_tmp
for i in `cat ./vnodeslist_tmp`; do echo "host $i" >> ./vnodeslist; done
rm ./vnodeslist_tmp


for i in `cat /tmp/distem_nodes_ip_*` ; do scp -rp /root/charm-6.5.1/ root@$i:; done
./charmrun ++p 32 ++nodelist ./vnodeslist ./stencil3d.prj 100 1

# grab results
for i in `cat /tmp/distem_nodes_ip_*` ; do scp -rp root@$i:/root/charm-6.5.1/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/stencil.prj.* .; done



