#!/usr/bin/ruby

require 'distem'

NODE1 = ARGV[0]
NODE2 = ARGV[1]
LATENCY = ARGV[2]

if_name = 'if0'

Distem.client do |cl|
  ifnet = {}
  # If no unit is given, we assume the value is in milliseconds
  LATENCY = "#{LATENCY}ms" unless LATENCY.is_a?(String) and LATENCY.include?('s')
  ifnet['input'] = {'latency' => { 'delay' => "#{LATENCY}" }}
  ifnet['output'] = {'latency' => { 'delay' => "#{LATENCY}" }}
  
  cl.viface_update NODE1, if_name, ifnet
  cl.viface_update NODE2, if_name, ifnet
  
end
