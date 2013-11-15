# Synchronously deliver published messages to subscribers. Subscriber gets the
# message only if waiting while the message is sent.
# Compare message-bus.rb. Also: subspaces/pubsub.rb.
#
# Run with the --show-final-state switch to verify that published tuples
# don't stay in the space.

require 'tupelo/app'

show_final_state = ARGV.delete "--show-final-state"

N_PUBS = 6
N_SUBS = 6
N_CHAN = 3

Tupelo.application do
  channels = (0...N_CHAN).map {|i| "channel #{i}"}
  
  N_PUBS.times do |pi|
    child do
      log.progname = "pub #{pi}"
      read ['start']
      delay = pi/10.0
      sleep delay
      ch = channels[ pi % channels.size ]
      pulse [ch, "pub #{pi} slept for #{delay} sec"]
    end
  end

  N_SUBS.times do |si|
    child passive: true do # passive means process will exit when pubs exit
      log.progname = "sub #{si}"
      ch = channels[ si % channels.size ]
      loop do
        log read [ch, nil]
      end
    end
  end
  
  if show_final_state
    child passive: true do
      log.progname = "final"
      def self.stop
        log read_all
        super
      end
      sleep
    end
  end

  local do
    write ['start']
  end
end
