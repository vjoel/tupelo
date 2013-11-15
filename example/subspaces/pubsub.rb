# Synchronously deliver published messages to subscribers. Subscriber gets the
# message only if waiting while the message is sent. Use subspaces to reduce
# total message traffic.
# Compare ../pubsub.rb.
#
# Run with the --show-final-state switch to verify that published tuples
# don't stay in the space.

require 'tupelo/app'

show_final_state = ARGV.delete "--show-final-state"

N_PUBS = 6
N_SUBS = 6
N_CHAN = 3

Tupelo.application do
  local do
    use_subspaces!

    N_CHAN.times do |i|
      define_subspace(
        tag:          i,
        template:     [
          {value: i},
          {type: "string"}
        ]
      )
    end

    define_subspace(
      tag:          "control",
      template:     [
        {value: "control"},
        nil
      ]
    )
  end
  
  N_PUBS.times do |pi|
    child subscribe: ["control"] do
      log.progname = "pub #{pi}"
      read [nil, 'start'] # first elt can only be 'control'
      delay = pi/10.0
      sleep delay
      tag = pi % N_CHAN
      pulse [tag, "pub #{pi} slept for #{delay} sec"]
    end
  end

  N_SUBS.times do |si|
    tag = si % N_CHAN
    child subscribe: [tag], passive: true do
      log.progname = "sub #{si} on tag #{tag}"
      loop do
        log read [nil, nil]
          # Note: match any pair, but in fact will only get [tag, ....]
          # because of subspaces.
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
    write ['control', 'start']
  end
end
