#!/usr/bin/ruby

require 'distem'

node_name = ARGV[0]

Distem.client do |cl|
  generator_desc = {}
  generator_desc['date'] = {}
  generator_desc['date']['distribution'] = 'uniform'

  # uniformally between min and max secs generate a value
  generator_desc['date']['min'] = 0
  generator_desc['date']['max'] = 1
  generator_desc['value'] = {}
  generator_desc['value']['distribution'] = 'uniform'
  generator_desc['value']['min'] = 0
  generator_desc['value']['max'] = 2500
#  generator_desc['date'] = { 'distribution' => 'weibull', 'scale'=>10, 'shape'=>3}
  cl.event_random_add({'type' => 'vcpu', 'vnodename' => node_name}, 'power', generator_desc)
  cl.event_manager_start
  sleep(30)
  cl.event_manager_stop
end

