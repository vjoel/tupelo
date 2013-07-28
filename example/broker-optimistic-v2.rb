# Modified in two ways:
# - use dsl
# - make it fit in a transaction do..end block

require 'tupelo/app'
require 'tupelo/app/monitor'
require 'tupelo/app/dsl'

N_PLAYERS = 10
VERBOSE = ARGV.delete "-v"

Tupelo::DSL.application do
  start_monitor if VERBOSE

  N_PLAYERS.times do
    # sleep rand / 10 # reduce contention -- could also randomize inserts
    child do
      me = client_id
      write name: me
      
      you = transaction do
        game = read_nowait(
          player1: nil,
          player2: me)
        break game["player1"] if game
      
        unless take_nowait name: me
          raise Tupelo::Client::TransactionFailure
        end

        you = take(name: nil)["name"]
        write(
          player1: me,
          player2: you)
        you
      end

      log "now playing with #{you}"
    end
  end
end
