#!/usr/bin/env ruby
#encoding: UTF-8

require 'pp'

local=false

if File.file? './lib/p3.rb'
  require './lib/p3.rb'
  puts "using local lib"
  local=true
else
  require 'p3'
end

p=P3.new do |pac|
  # this is run when we get packet from server
  puts "we got packet! #{pac}"
end

pac={
  proto:'U',
  mac: "11:22",
  ip: "20.20.20.21",
  port: 258,
  data:"tadaa 123",
}
pp pac
d=p.pack pac
pp d

d2=p.unpack d.unpack("c*")[1..-1]
pp d2

"tadaa".split("").each do |ch|
  if not p.inchar(ch.ord)
    print ch
  end
end

d.split("").each do |ch|
  if not p.inchar(ch.ord)
    print ch
  end
end
puts "sleeping 60 sec..."
sleep 60

p.shutdown

