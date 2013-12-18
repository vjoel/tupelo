# see also ../parallel.rb and ../remote.rb

require 'tupelo/app/remote'

tunnel = !!ARGV.delete("--tunnel")

hosts = ARGV.shift or abort "usage: #$0 <ssh-hostname>,<ssh-hostname>,..."
hosts = hosts.split(",")

Tupelo.tcp_application do
  hosts.each do |host|
    remote host: host, passive: true, tunnel: tunnel, eval: %{
      loop do
        len = take([String])[0].size
        write [len]
      end
    }
  end

  local do
    input = [ ["We are going to"], ["calcula"], ["te the len"],
              ["gth of this "], ["sentence."] ]
    write *input
    sum = 0
    input.size.times do
      sum += take([Numeric])[0]
    end
    log "sum = #{sum}, correct sum = #{input.flatten.join.size}"
  end
end
