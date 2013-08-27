# simple use of remote to start process on remote host and connect it to
# the tupelo app

require 'tupelo/app'

host = ARGV.shift or abort "usage: #$0 <ssh-hostname>"

Tupelo.application(
  seqd_addr:  [:tcp, nil, 0], ## these should be defaults?
  cseqd_addr: [:tcp, nil, 0],
  arcd_addr:  [:tcp, nil, 0]) do

  remote host: host do
    write host: `hostname`.chomp, mode: "drb"
      # this actually returns local hostname, because the block executes
      # locally -- only the tupelo ops are remote. So this mode is really
      # only for examples and tests, not production.
  end
  
  remote host: host, eval: %{
    write host: `hostname`.chomp, mode: "eval"
  }
  
#  remote host, dir: "", run: "", args: []
  
  local do
    2.times do
      log take host: nil, mode: nil
    end
  end
end
