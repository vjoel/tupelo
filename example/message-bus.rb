# Asynchronously deliver messages via a shared "data bus" aka "data hub".
# A message is written to a channel. It remains there until a new value is
# written to the channel. A reader can pick it up at any time. Compare
# pubsub.rb.
#
# Run with the --show-final-state switch to verify that the last tuple
# written to a channel does stay there.

require 'tupelo/app'

show_final_state = ARGV.delete "--show-final-state"

N_PUBS = 6
N_SUBS = 6
N_CHAN = 3

Tupelo.application do
  channels = (0...N_CHAN).map {|i| "channel #{i}"}
  
  N_PUBS.times do |pi|
    child do
      read ['start']
      delay = pi
      sleep delay
      ch = channels[ pi % channels.size ]
      transaction do
        take_nowait [ch, nil]
        write [ch, "pub #{pi} slept for #{delay} sec"]
      end
    end
  end

  N_SUBS.times do |si|
    child passive: true do # passive means process will exit when pubs exit
      log.progname = "sub #{si}"
      ch = channels[ si % channels.size ]
      loop do
        sleep 1
        t = read_nowait [ch, nil]
        log t if t
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
