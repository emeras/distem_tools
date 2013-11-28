#!/usr/bin/ruby

require 'distem'

# Name of node to disturb (as given in distem --get-vnode-info)
node_name = ARGV[0]
# Duration of disturbance
event_duration = ARGV[1].to_i

# Event Frequencies in seconds -- min and max values for uniform law parameters
event_freq_min = 1
event_freq_max = 120

Distem.client do |cl|
  generator_desc['date'] = {}
  generator_desc['date']['distribution'] = 'uniform'
  generator_desc['date']['min'] = event_freq_min
  generator_desc['date']['max'] = event_freq_max
  cl.event_random_add({ 'type' => 'vnode', 'vnodename' => node_name}, 'churn', generator_desc)
  cl.event_manager_start
  sleep(event_duration)
  cl.event_manager_stop
end
 
