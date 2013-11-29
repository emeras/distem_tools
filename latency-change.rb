#!/usr/bin/ruby:

require 'distem'

NODE1 = ARGV[0]
NODE2 = ARGV[1]
LATENCY = ARGV[2]

if_name = 'if0'

Distem.client do |cl|
  ifnet = {}
  ifnet['input'] = {'latency' => { 'delay' => "#{LATENCY}ms" }}
  ifnet['output'] = {'latency' => { 'delay' => "#{LATENCY}ms" }}
  
  cl.viface_update NODE1, if_name, ifnet
  cl.viface_update NODE2, if_name, ifnet
  
end
