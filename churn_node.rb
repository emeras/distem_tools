#!/usr/bin/ruby

require 'distem'

# Name of node to disturb (as given in distem --get-vnode-info)
node_name = ARGV[0]
# Duration of disturbance
event_duration = ARGV[1].to_i

# Event Frequencies in seconds -- min and max values for uniform law parameters
# event_freq_min = 1
# event_freq_max = 10

generator_desc = {}
Distem.client do |cl|
  #generator_desc['date'] = {}
  #generator_desc['date']['distribution'] = 'uniform'
  #generator_desc['date']['min'] = event_freq_min
  #generator_desc['date']['max'] = event_freq_max
  
  ### About Weibull values
  ### See this presentation: http://web.eecs.utk.edu/~herault/slides/slides-ics13-tutorial.pdf
  ### Values from literature are 
  ###   * Shape parameters for Weibull: k = 0.5 or k = 0.7
  ###   * MTBF of one processor: between 1 and 125 years
  ### /!\ We have to take a short MTBF value to have (at least) one failure.
  failure_scale = 3600#*24*365
  failure_shape = 0.5
  generator_desc['date'] = { 'distribution' => 'weibull', 'scale'=>failure_scale, 'shape'=>failure_shape}
  
  if(node_name == "all")
    nodes = []
    cl.vnodes_info.each {|n| nodes << n['name']}
    nodes.each { |n|          
      cl.event_random_add({ 'type' => 'vnode', 'vnodename' => n}, 'churn', generator_desc)
    }
  else  
    cl.event_random_add({ 'type' => 'vnode', 'vnodename' => node_name}, 'churn', generator_desc)
  end
  begin
    cl.event_manager_start
  rescue Distem::Lib::ClientError => e
    puts "Unable to start event manager (maybe it is already started?)"
  end 
  sleep(event_duration)
  cl.event_manager_stop
  puts "Restarting nodes..."
  if(node_name == "all")
    nodes_to_restart = []
    cl.vnodes_info.each {|n| 
      if(n['status'] != 'RUNNING')
        nodes_to_restart << n['name']
      end                    
    }
    cl.vnodes_start(nodes_to_restart, async=false)
  else  
    cl.vnode_start(node_name, async=false)
  end
end
 
