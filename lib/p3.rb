#!/usr/bin/env ruby
#encoding: UTF-8

require "pp"
require 'socket'

class P3

  P3_START='~'.ord
  P3_END='^'.ord
  P3_ESC='#'.ord

  def initialize(hash={},&block)
    @p3mode=false
    @p3start=0
    @p3buf=[]
    @p3esc=false
    @clients={}
    @block=block
  end

  def unpack buf #buils object from packet byte array
    blen=buf.size
    #puts "GOT: buf<#{buf}> buflen=#{buf.size}"
    return if blen<4
    check2=0
    buf[0...blen-1].each do |b|
      check2^=b
    end
    i=0
    proto=buf[i].chr
    i+=1
    mac=sprintf "%02X:%02X",buf[i],buf[i+1]
    i+=4
    ip=sprintf "%d.%d.%d.%d",buf[i+3],buf[i+2],buf[i+1],buf[i]
    i+=4
    port=buf[i+1]*0x100+buf[i]
    i+=2
    len=buf[i]
    i+=1
    check=buf[i+len]
    data=buf[i...i+len]
    pac={
      proto:proto,
      mac: mac,
      ip: ip,
      port:port,
      data:data,
    }
    #puts "proto=#{proto},mac=#{mac},ip=#{ip},socket=#{socket},len=#{len},check=#{check}==#{check2},data='#{data.pack("C*")}'"
  end



  def pack pac #builds p3 packet from  pac object
    #pp pac
    begin
      buf=[]
      buf<<pac[:proto].ord
      macs=pac[:mac].split(":")
      buf<<macs[0].to_i(16)
      buf<<macs[1].to_i(16)
      buf<<0
      buf<<0
      ips=pac[:ip].split(".")
      buf<<ips[3].to_i
      buf<<ips[2].to_i
      buf<<ips[1].to_i
      buf<<ips[0].to_i
      buf<<(pac[:port]&0xff)
      buf<<pac[:port]/0x100
      buf<<pac[:data].size
      buf+=pac[:data].unpack("C*")
      check=0
      buf.each do |b|
        check^=b
      end
      buf<<check
      #pp buf
      pp "#{P3_START.chr}#{buf.pack("C*")}#{P3_END.chr}"
      return "#{P3_START.chr}#{buf.pack("C*")}#{P3_END.chr}"
    rescue => e
      p e
      p e.backtrace
    end
    return nil
  end

  def p3_packet_in buf
    #puts "packet in #{buf}"
    pac= unpack buf
    return if not pac
    #pp pac
    #pp @clients
    if pac[:proto]=="P" #local keep-alive-ping
      puts "yeah -- we got ping -- let's pong"
      pac={
        proto:'P',
        mac: "00:00",
        ip: "0.0.0.0",
        port:0,
        data:"pong",
      }
      #pp pac
      # received return packet from server!
      if @block
        @block.call pac
      end

    elsif pac[:proto]=="U" #udp to internet
      if not @clients[pac[:mac]]
        #puts "new client #{pac[:mac]}"
        @clients[pac[:mac]]={socket: UDPSocket.new,created:Time.now,count_r:0, count_s:0}
        @clients[pac[:mac]][:thread]=Thread.new(pac[:mac]) do |my_mac|
          loop do
            begin
              r,stuff=@clients[my_mac][:socket].recvfrom(2000) #get_packet --high level func!
              ip=stuff[2]
              port=stuff[1]
              #puts "got reply '#{r}' from server #{ip}:#{port} to our mac #{my_mac}"
              pac={
                proto:'U',
                mac: my_mac,
                ip: ip,
                port:port,
                data:r,
              }
              #pp pac
              # received return packet from server!
              if @block
                @block.call pac
              end
              #$sp.write pack pac
              @clients[my_mac][:last_r]=Time.now
              @clients[my_mac][:count_r]+=1
             rescue => e
              puts "thread dies..."
              p e
              p e.backtrace
            end
          end
        end
        #pp @clients
      end
      @clients[pac[:mac]][:socket].send(pac[:data].pack("C*"), 0, pac[:ip], pac[:port])
      _,port,_,_ = @clients[pac[:mac]][:socket].addr
      @clients[pac[:mac]][:gw_port]=port
      @clients[pac[:mac]][:last_s]=Time.now
      @clients[pac[:mac]][:count_s]+=1
      puts "sent #{pac}\r\n"
      #pp @clients
    end
  end

  def shutdown
    @clients.each do |k,c|
      if c[:socket]
        c[:socket].close
        puts "closed #{k}: #{c[:socket]}"
      end
      if c[:thread]
        c[:thread].kill
        puts "killed #{k}: #{c[:thread]}"
      end
    end
    @clients={}
  end

  def inchar ch
    #puts "got:#{ch}"
    if ch==P3_START and not @p3esc and not @p3mode
      @p3mode=true
      @p3start=Time.now
      @p3buf=[]
    elsif ch==P3_END and not @p3esc and @p3mode
      @p3mode=false
      p3_packet_in @p3buf
      @p3buf=[]
    else
      if not @p3mode
        return false #not done, please process .. show to user
      else
        if @p3esc
          @p3esc=false
        elsif ch==P3_ESC
          @p3esc=true
          return true
        end
        @p3buf<<ch
      end
    end
    return true #char was done -- do not process
  end

end
