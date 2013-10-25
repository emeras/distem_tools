#!/usr/bin/ruby
require 'distem'

pnodes=IO.readlines('/root/DISTEM_NODES').join.split("\n")
raise 'Distem requires at least one physical machines' unless pnodes.size >= 1

nodelist = []
pnodes.each_with_index() do |elem, i|
  curr_node="node-#{i}_0"
  nodelist << curr_node
end


# Describing the resources we are working with
ifname = 'if0'
node1 = {
  'name' => 'node-1_0',
  'address' => nil
}
node2 = {
  'name' => 'node-2_0',
  'address' => nil
}

Distem.client do |cl|


  nodelist.each do |node|
    cl.vnode_execute(node, "sh /root/set_gw.sh ; echo 'export http_proxy=\"http://proxy:3128\"' >> /root/.bashrc")
  end




  # Getting the -automatically affected- address of each virtual nodes
  # virtual network interfaces
  node1['address'] = cl.viface_info(node1['name'],ifname)['address'].split('/')[0]
  node2['address'] = cl.viface_info(node2['name'],ifname)['address'].split('/')[0]
  # Creating the files we will use in our experimentation
  cl.vnode_execute(node1['name'],
    'mkdir -p /tmp/src ; cd /tmp/src ; \ 
     for i in `seq 1 100`; do \ 
      dd if=/dev/zero of=$i bs=1K count=50; \ 
     done'
  )
  # Printing the current latency
  start_time = Time.now.to_f
  cl.vnode_execute(node1['name'], 'hostname')
  puts "Latency without any limitations #{Time.now.to_f - start_time}"
  # Preparing the description structure that will be used to
  # update virtual network interfaces latency
  desc = {
    'output' => {
      'latency' => {
        'delay' => nil
      }
    }
  }
  # Starting our experiment for each specified latencies
  puts 'Starting tests'
  latencies.each do |latency|
    puts "Latency #{latency}"
    results['scp'][latency] = []
    results['rsync'][latency] = []
    # Update the latency description on virtual nodes
    desc['output']['latency']['delay'] = latency
    cl.viface_update(node1['name'],ifname,desc)
    cl.viface_update(node2['name'],ifname,desc)
    iterations.times do |iter|
      puts "\tIteration ##{iter}"
      # Launch SCP test
      # Cleaning target directory on node2
      cl.vnode_execute(node2['name'], 'rm -rf /tmp/dst')
      # Starting the copy from node1 to node2
      start_time = Time.now.to_f
      cl.vnode_execute(node1['name'],
        "scp -rq /tmp/src #{node2['address']}:/tmp/dst"
      )
      results['scp'][latency] << Time.now - start_time
      # Launch RSYNC test
      # Cleaning target directory on node2
      cl.vnode_execute(node2['name'], 'rm -rf /tmp/dst')
      # Starting the copy from node1 to node2
      start_time = Time.now
      cl.vnode_execute('node-1',
        "rsync -r /tmp/src #{node2['address']}:/tmp/dst"
      )
      results['rsync'][latency] << Time.now - start_time
    end
  end
end
