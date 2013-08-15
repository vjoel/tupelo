# Modified in two ways:
# - use simplified block syntax
# - make it fit in a transaction do..end block

require 'tupelo/app'

N_PLAYERS = 10

Tupelo.application do
  N_PLAYERS.times do
    # sleep rand / 10 # reduce contention -- could also randomize inserts
    child do
      me = client_id
      you = nil
      write name: me
      
      transaction do
        game = read_nowait(
          player1: nil,
          player2: me)

        if game
          you = game["player1"]
          break
        end
      
        take_nowait(name: me) or fail!
        you = take(name: nil)["name"]
        write(
          player1: me,
          player2: you)
      end

      log "now playing with #{you}"
    end
  end
end
