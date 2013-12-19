# See also ../parallel.rb and ../remote.rb.
#
# To run this example over an ssh tunnel, either pass "--tunnel" on the command
# line (the switch is parsed by the app framework) or explicitly pass the
# `tunnel: true` argument to the #remote call below. The --tunnel switch works
# for all examples and other programs based on 'tupelo/app'.

require 'tupelo/app/remote'

hosts = ARGV.shift or abort "usage: #$0 <ssh-hostname>,<ssh-hostname>,..."
hosts = hosts.split(",")

Tupelo.tcp_application do
  hosts.each do |host|
    remote host: host, passive: true, eval: %{
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
