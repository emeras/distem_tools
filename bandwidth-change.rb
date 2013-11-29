#!/usr/bin/ruby:

require 'distem'

NODE1 = ARGV[0]
NODE2 = ARGV[1]
BANDWIDTH = ARGV[2]

if_name = 'if0'

Distem.client do |cl|
  ifnet = {}
  ifnet['input'] = { 'bandwidth' => {'rate' => "#{BANDWIDTH}mbit"} }  
  ifnet['output'] = { 'bandwidth' => {'rate' => "#{BANDWIDTH}mbit"} }
  
  cl.viface_update NODE1, if_name, ifnet
  cl.viface_update NODE2, if_name, ifnet
  
end













