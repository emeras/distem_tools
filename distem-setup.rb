#!/usr/bin/ruby
require 'distem'
require 'thread'
require 'socket'
require 'pp'
require 'getoptlong'
####


###############################
#### CLASSES and Functions ####
###############################

def usage_message
    <<EOS
Usage distem-setup [OPTIONS]

        OPTIONS:
                --vm | -m <vm per host>: define how many vm per host are to be created (default is one)
                --vcore | -c <core per vm>: define how many core per vm are to be setup (default is one)
                --shared | -s: use shared vnode images (default is false)
                --noauto | -n: do not use Distem's automatic VM placement -- VM will be placed sequentially per pnode.
EOS
end
opts = GetoptLong.new(
[ "--shared","-s",              GetoptLong::NO_ARGUMENT ],
[ "--help", "-h",             GetoptLong::NO_ARGUMENT ],
[ "--vm","-m",              GetoptLong::REQUIRED_ARGUMENT ],
[ "--vcore","-c",              GetoptLong::REQUIRED_ARGUMENT ],
[ "--noauto","-n",              GetoptLong::NO_ARGUMENT ],
)
############################
### ENV VAR needed. # TODO: set as option or other cleaner method
FSIMG=ENV["FSIMG"]
NODES=ENV["NODES"]
NET=ENV["NET"]
SSH_KEY=ENV["SSH_KEY"]
IPFILE=ENV["IPFILE"]
CPU_ALGO=ENV["CPU_ALGO"]
############################
auto_placement = true
shared = false
vm_per_host = 1
core_per_vm = 1
opts.each do |option, value| 
        if (option == "--help")
            puts usage_message
            exit 0
        elsif (option == "--shared")
                shared = true
        elsif (option == "--vm")
                vm_per_host = value.to_i #if value.to_i >1
        elsif (option == "--vcore")
                core_per_vm = value.to_i #if value.to_i >1   
	elsif (option == "--noauto")
		auto_placement = false
  end
end

#######################################################################
#### Main ####
#######################################################################
pnodes=IO.readlines(NODES).join.split("\n")
raise 'Distem requires at least one physical machines' unless pnodes.size >= 1
g5k_net=IO.readlines(NET).join
vnet = {
  'name' => 'vnet0',
  'address' => g5k_net, 
  'interface' => 'if0'  
}
private_key = IO.readlines("/root/.ssh/#{SSH_KEY}").join
public_key = IO.readlines("/root/.ssh/#{SSH_KEY}.pub").join
sshkeys = {
  'private' => private_key,
  'public' => public_key
}
iplist = []


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
  # Retrieve PNodes topology and info, update Pnodes setup (algos...)
  pnodes_info = {}
  pnodes.each do |node|
    pnodes_info[node] = cl.pnode_info(target = node)
    cl.pnode_update(target = node, desc = { "algorithms"=>{"cpu"=>CPU_ALGO} }) if defined? CPU_ALGO
  end
  vnodelist = []
  pnodes_info.each do |key, info|
    pnode = key.dup
    #pnode.slice! ".grid5000.fr"   # this is for multisite use.
    pnode.slice!(/\..*\.grid5000\.fr/)
    ncores = info['cpu']['cores'].size
    #memory = info['memory']['capacity']
    #swap = info['memory']['swap']
    
    # check that user required toplogy is ok with what we have
    if( (core_per_vm > 0)  && (ncores < vm_per_host * core_per_vm) )
	raise ArgumentError, 'In arguments --vm and/or --vcore: not enough physical resources for this topology.' 
    end
        
    ###################################
    (1..vm_per_host).each { |i|
      if (auto_placement == true)
        vnodelist << "node#{i}"            
      else
        vnodelist << "#{pnode}_#{i}"         
      end
    }
    vnodes_config = {}
    vnodes_config['vifaces'] = [{'name' => vnet['interface'], 'vnetwork' => vnet['name']}]
    vnodes_config['ssh_key'] = sshkeys
    vnodes_config['host'] = pnode if (auto_placement == false)
    if (shared == true)
      vnodes_config['vfilesystem'] = { 'image' => FSIMG, 'shared' => true, 'sharedpath' => "/tmp/distem/rootfs-shared/" }
    else
      vnodes_config['vfilesystem'] = { 'image' => FSIMG, 'shared' => false, 'cow' => true }
    end
    
    res = cl.vnodes_create(vnodelist, vnodes_config)
    res.each { |r| iplist << r['vifaces'][0]['address'].split('/')[0] }
    
    ### Configure CPU -- TODO: put this before vnodes_create()
    if core_per_vm > 0
      vnodelist.each { |node|
        cl.vcpu_create(node, frequency = 1.0, 'ratio', corenb = core_per_vm)
      }
    end  
    ###################################
    
    ###################################
#     for i in 1..vm_per_host
#       node = "#{pnode}_#{i}"
#       vnodelist << node
#       cl.vnode_create(node, { 'host' => pnode }, sshkeys)
#       if (shared == true)
# 	cl.vfilesystem_create(node, { 'image' => FSIMG, 'shared' => true, 'sharedpath' => "/tmp/distem/rootfs-shared/" })
#       else
# 	cl.vfilesystem_create(node, { 'image' => FSIMG, 'shared' => false, 'cow' => true })
#       end
#       iface = cl.viface_create(node, vnet['interface'], { 'vnetwork' => vnet['name'] })
#       iplist << iface['address'].split('/')[0]
# 
#       cl.vcpu_create(node, frequency = 1.0, 'ratio', corenb = core_per_vm) if core_per_vm > 0
#     end
    ###################################
    
  end

  puts 'Starting VNodes'
  #puts "IPs: #{iplist}"
  # Start nodes
  cl.vnodes_start(vnodelist, async=false)
  puts "Waiting for vnodes to be here..."
  ret = cl.wait_vnodes({'timeout' => 1800, 'vnodes'=>vnodelist, 'port' => 22}) # wait for ssh to be running on all nodes -- 30mn timeout
  if ret
    puts "Setting global /etc/hosts"
    cl.set_global_etchosts
    puts "Setting global ARP tables"
    a = Time.now.to_f
    cl.set_global_arptable
    puts "done in #{Time.now.to_f - a} seconds"
    File.open(IPFILE,'w') do |f|
      iplist.each{ |ip| f.puts(ip) }
    end
    puts 'Finalizing VNodes Config'
    vnodelist.each do |node|
      # Configure network on vnodes
      cl.vnode_execute(node, "sh /root/set_gw.sh ; echo 'export http_proxy=\"http://proxy:3128\"' >> /root/.bashrc")
    end
    puts 'Terminated...'
  else
    puts "vnodes are unreachable"
  end
end
