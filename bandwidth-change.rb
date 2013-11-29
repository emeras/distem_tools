#!/usr/bin/ruby

require 'distem'

NODE1 = ARGV[0]
NODE2 = ARGV[1]
BANDWIDTH = ARGV[2]

if_name = 'if0'

Distem.client do |cl|
  ifnet = {}
  # If no unit is given, we assume the value is in Mbps
  BANDWIDTH = "#{BANDWIDTH}mbps" unless BANDWIDTH.is_a?(String) and BANDWIDTH.include?('s')
  ifnet['input'] = { 'bandwidth' => {'rate' => "#{BANDWIDTH}"} }  
  ifnet['output'] = { 'bandwidth' => {'rate' => "#{BANDWIDTH}"} }
  
  cl.viface_update NODE1, if_name, ifnet
  cl.viface_update NODE2, if_name, ifnet
  
end













