#!/usr/bin/ruby
# Import the Distem module
require 'distem'
# The path to the compressed filesystem image
# We can point to local file since our homedir is available from NFS
FSIMG="file:///home/ejeanvoine/public/distem/distem-fs-wheezy.tar.gz"
# Getting the physical nodes list which is set in the
# environment variable 'DISTEM_NODES' by distem-bootstrap
pnodes=IO.readlines('/root/DISTEM_NODES').join.split("\n")
raise 'Distem requires at least one physical machines' unless pnodes.size >= 1
# This ruby hash table describes our virtual network
g5k_net=IO.readlines('/root/G5K_NET').join
vnet = {
  'name' => 'vnet0',
  'address' => g5k_net
}
# Read SSH keys
private_key = IO.readlines('/root/.ssh/id_dsa').join
public_key = IO.readlines('/root/.ssh/id_dsa.pub').join
sshkeys = {
  'private' => private_key,
  'public' => public_key
}


folding_factor = 1

# Connect to the Distem server (on http://localhost:4567 by default)
Distem.client do |cl|
  # Start by creating the virtual network
  puts 'Creating VNetwork'
  begin
    cl.vnetwork_create(vnet['name'], vnet['address'])
  rescue "Unable to create network."
  end
  # Creating virtual nodes
  puts 'Creating VNodes'
  # Retrieve PNodes topology and info
  pnodes_info = {}
  pnodes.each do |node|
    pnodes_info[node] = cl.pnode_info(target = node)
  end
  vnodelist = []
  pnodes_info.each do |key, info|
    pnode = key.dup
    #pnode.slice! ".grid5000.fr"
    pnode.slice!(/\..*\.grid5000\.fr/)
    ncores = info['cpu']['cores'].size
    memory = info['memory']['capacity']
    swap = info['memory']['swap']

    for i in 1..folding_factor
      node = "#{pnode}_#{i}"
      vnodelist << node
      cl.vnode_create(node, { 'host' => pnode }, sshkeys)
      # ,'shared' => false, 'cow' => true
      cl.vfilesystem_create(node, { 'image' => FSIMG, 'shared' => true, 'cow' => true})
      cl.viface_create(node, 'if0', { 'vnetwork' => vnet['name'] })
      cl.vcpu_create(node, corenb = ncores, frequency = 1.0) if folding_factor ==1
      #cl.vmem_create(memory, swap) if folding_factor == 1
    end

  end

  puts 'Starting VNodes'
  # Start nodes in parallel
  cl.vnodes_start(vnodelist, async = false)

  puts 'Waiting for VNodes to boot...'
  sleep 120


  puts 'Setting VNodes Network info'
  # Fill arp table and etc hosts info
  cl.set_global_etchosts 
  cl.set_global_arptable

  puts 'Finalizing VNodes Config'
  vnodelist.each do |node|
    ## pp node
    #cl.vnode_execute(node, 'hostname')
    cl.vnode_execute(node, "sh /root/set_gw.sh ; echo 'export http_proxy=\"http://proxy:3128\"' >> /root/.bashrc ; source ~/.bashrc")
    cl.vnode_execute(node, "apt-get install -y liblz-dev lib32z-dev")
  end

  puts 'Terminated...'
end
