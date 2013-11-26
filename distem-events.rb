#!/usr/bin/ruby

require 'distem'

# Name of node to disturb (as given in distem --get-vnode-info)
node_name = ARGV[0]
# Duration of disturbance
event_duration = ARGV[1]

# Event Frequencies in seconds -- min and max values for uniform law parameters
event_freq_min = 1
event_freq_max = 120


# available distributions: 
#   uniform - params: min, max 
#   exponential - params: rate
#   weibull - params: scale, shape


# Distribution specific based events
Distem.client do |cl|

  freq_values = cl.pnode_info(target = node_name)['cpu']['cores']['frequencies']
  max = freq_values.max.dup
  max.slice!(/ MHz/)
  max = max.to_i - 1  # BUG: do not set to max, problem with killing distem hogs process
  min = 2             # BUG: set min > 1 as these are special values (mean cpu percentage)
  
  generator_desc = {}
  generator_desc['date'] = {}
  generator_desc['date']['distribution'] = 'uniform'

  # uniformally between min and max secs generate a value
  generator_desc['date']['min'] = event_freq_min
  generator_desc['date']['max'] = event_freq_max
  generator_desc['value'] = {}
  generator_desc['value']['distribution'] = 'uniform'
  generator_desc['value']['min'] = min
  generator_desc['value']['max'] = max
#  generator_desc['date'] = { 'distribution' => 'weibull', 'scale'=>10, 'shape'=>3}
  cl.event_random_add({'type' => 'vcpu', 'vnodename' => node_name}, 'power', generator_desc)
  cl.event_manager_start
  sleep(event_duration)
  cl.event_manager_stop
end


# # Now with a trace
# Distem.client do |cl|
#   trace = {10 => 1000, 15 => 2500, 20 => 1}
#   resource = {'type' => 'vcpu', 'vnodename' => node_name}
#   cl.event_trace_add(resource, 'power', trace)
#   cl.event_manager_start
#   sleep(event_duration)
#   cl.event_manager_stop
# end

