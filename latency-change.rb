#!/usr/bin/ruby

require 'distem'

NODE1 = ARGV[0]
NODE2 = ARGV[1]
LATENCY = ARGV[2]
latency = LATENCY

if_name = 'if0'

Distem.client do |cl|
  ifnet = {}
  # If no unit is given, we assume the value is in milliseconds
  latency = "#{latency}ms" unless latency.is_a?(String) and latency.include?('s')
  ifnet['input'] = {'latency' => { 'delay' => "#{latency}" }}
  ifnet['output'] = {'latency' => { 'delay' => "#{latency}" }}
  
  cl.viface_update NODE1, if_name, ifnet
  cl.viface_update NODE2, if_name, ifnet
  
end
