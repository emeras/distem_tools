#!/usr/bin/ruby
# Import the Distem module
require 'distem'
require 'thread'
require 'socket'
require 'pp'
####

class SlidingWindow
  def initialize(size)
    @queue = []
    @lock = Mutex.new
    @finished = false
    @size = size
  end

  def add(t)
    @queue << t
  end

  def run
    @queue = @queue.reverse
    tids = []
    (1..@size).each {
      tids << Thread.new {
        while !@finished do
          task = nil
          @lock.synchronize {
            if @queue.size > 0
              task = @queue.pop
            else
              @finished = true
            end
          }
          if task
            if task.is_a?(Proc)
              task.call
            else
              system(task)
            end
          end
        end
      }
    }
    tids.each { |tid| tid.join }
  end
end

def port_open?(ip, port)
  begin
    s = TCPSocket.new(ip, port)
    s.close
    return true
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    return false
  end
end

def wait_ssh(host, timeout = 120)
    def now()
      return Time.now.to_f
    end
    bound = now() + timeout
    while now() < bound do
        t = now()
        return true if port_open?(host, 22)
        dt = now() - t
        sleep(0.5 - dt) if dt < 0.5
    end
    return false
end


####
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


folding_factor = ARGV[0].to_i
if (!defined? folding_factor) || folding_factor<1
  folding_factor = 1
end
now = `date +%s`.to_i
ipfile = "/tmp/distem_nodes_ip_#{now}"
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
      cl.vfilesystem_create(node, { 'image' => FSIMG, 'shared' => true, 'cow' => true})
      iface = cl.viface_create(node, 'if0', { 'vnetwork' => vnet['name'] })
      iplist << iface['address'].split('/')[0]

      cl.vcpu_create(node, corenb = ncores, frequency = 1.0) if folding_factor ==1
      #cl.vmem_create(memory, swap) if folding_factor == 1
    end

  end

  puts 'Starting VNodes'
  puts "IPs: #{iplist}"
  # Start nodes
  cl.vnodes_start(vnodelist, async=true)
  puts "Waiting for vnodes to be here..."
  lock = Mutex.new
  nb_reachable = 0
  win = SlidingWindow.new(100)
  iplist.each { |ip|
    p = Proc.new {
      exit! 1 if not wait_ssh(ip, 1200)
      #puts "#{ip} is here"
      lock.synchronize {
        nb_reachable += 1
        puts "#{nb_reachable}/#{nb_vnodes}" if ((nb_reachable % 100) == 0)
      }
    }
    win.add(p)
  }
  win.run
  puts "#{nb_reachable} nodes are here"

  puts "Setting global /etc/hosts"
  cl.set_global_etchosts
  puts "Setting global ARP tables"
  cl.set_global_arptable

  File.open(ipfile,'w') do |f|
    iplist.each{ |ip| f.puts(ip) }
  end

  puts 'Finalizing VNodes Config'
  vnodelist.each do |node|
    cl.vnode_execute(node, "sh /root/set_gw.sh ; echo 'export http_proxy=\"http://proxy:3128\"' >> /root/.bashrc ; source ~/.bashrc")
    cl.vnode_execute(node, "apt-get install -y liblz-dev lib32z-dev")
  end

  puts 'Terminated...'
end