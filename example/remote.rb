# simple use of remote to start process on remote host and connect it to
# the tupelo app

require 'tupelo/app/remote'

host = ARGV.shift or abort "usage: #$0 <ssh-hostname>"

Tupelo.tcp_application do
  remote host: host do
    write host: `hostname`.chomp, mode: "drb", client: client_id
      # this actually returns local hostname, because the block executes
      # locally -- only the tupelo ops are remote. So this mode is really
      # only for examples and tests, not production.
  end
  
  remote host: host, log: true, eval: %{
    write host: `hostname`.chomp, mode: "eval", client: client_id
  }
  # rather than embed large chunks of code in the string, it's better to
  # load or require a file and pass self (which is a Client instance) to
  # a method in that file.
  
  remote host: host, log: true, passive: true, eval: %{
    write host: `hostname`.chomp, mode: "eval", client: client_id
    sleep # since passive, app can stop this process
  }
  
  local do
    3.times do
      log take host: nil, mode: nil, client: nil
    end
  end
end
