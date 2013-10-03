# Clients attempt to pair up, using a distributed broker algorithm and a lock
# tuple.

require 'tupelo/app'

N_PLAYERS = 10

token = ["token"] # only the holder of the token can arrange games

Tupelo.application do
  local do
    write token
  end
  
  N_PLAYERS.times do
    child do
      me = client_id

      take token # bottleneck and fragile until 'write token'
      other_player = read_nowait(name: nil)
        # sleep 1 # program takes ~N_PLAYERS sec to finish

      if other_player
        take other_player
        write(
          player1: me,
          player2: other_player["name"])
        write token
        you = other_player["name"]

      else
        write(name: me)
        write token
        game = read(
          player1: nil,
          player2: me)
        you = game["player1"]
      end

      log "now playing with #{you}"
    end
  end
end
