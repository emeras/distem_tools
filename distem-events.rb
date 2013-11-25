#!/usr/bin/ruby

require 'distem'

node_name = ARGV[0]


# available distributions: 
#   uniform - params: min, max 
#   exponential - params: rate
#   weibull - params: scale, shape


# Distribution specific based events
Distem.client do |cl|
  generator_desc = {}
  generator_desc['date'] = {}
  generator_desc['date']['distribution'] = 'uniform'

  # uniformally between min and max secs generate a value
  generator_desc['date']['min'] = 60
  generator_desc['date']['max'] = 120
  generator_desc['value'] = {}
  generator_desc['value']['distribution'] = 'uniform'
#   generator_desc['value']['min'] = 1
#   generator_desc['value']['max'] = 2500
  generator_desc['value']['min'] = 10
  generator_desc['value']['max'] = 2499
#  generator_desc['date'] = { 'distribution' => 'weibull', 'scale'=>10, 'shape'=>3}
  cl.event_random_add({'type' => 'vcpu', 'vnodename' => node_name}, 'power', generator_desc)
  cl.event_manager_start
  sleep(30)
  cl.event_manager_stop
end


# # Now with a trace
# Distem.client do |cl|
#   trace = {10 => 1000, 15 => 2500, 20 => 1}
#   resource = {'type' => 'vcpu', 'vnodename' => node_name}
#   cl.event_trace_add(resource, 'power', trace)
#   cl.event_manager_start
#   sleep(30)
#   cl.event_manager_stop
# end

