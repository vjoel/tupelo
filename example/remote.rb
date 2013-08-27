# simple use of remote to start process on remote host and connect it to
# the tupelo app

require 'tupelo/app/remote'

host = ARGV.shift or abort "usage: #$0 <ssh-hostname>"

Tupelo.application(
  seqd_addr:  [:tcp, nil, 0], ## these should be defaults?
  cseqd_addr: [:tcp, nil, 0],
  arcd_addr:  [:tcp, nil, 0]) do

  remote host: host do
    write host: `hostname`.chomp, mode: "drb", client: client_id
      # this actually returns local hostname, because the block executes
      # locally -- only the tupelo ops are remote. So this mode is really
      # only for examples and tests, not production.
  end
  
  remote host: host, eval: %{
    write host: `hostname`.chomp, mode: "eval", client: client_id
  }
  
#  remote host, dir: "", run: "", args: []
  
  local do
    2.times do
      log take host: nil, mode: nil, client: nil
    end
  end
end
