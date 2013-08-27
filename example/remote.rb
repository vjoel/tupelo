# simple use of remote to start process on remote host and connect it to
# the tupelo app

require 'tupelo/app'

host = ARGV.shift or abort "usage: #$0 <ssh-hostname>"

Tupelo.application do
  remote host: host do
    write host: `hostname`
  end
  
#  remote host, eval: %w{
#    write {host: `hostname`}
#  }
#  
#  remote host, dir: "", run: "", args: []
  
  local do
    log read host: nil
  end
end
