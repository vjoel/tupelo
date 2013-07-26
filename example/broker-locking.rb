# Clients attempt to pair up, using a distributed broker algorithm and a lock
# tuple.

require 'tupelo/app'
require 'tupelo/app/monitor'

N_PLAYERS = 10
VERBOSE = ARGV.delete "-v"

token = ["token"] # only the holder of the token can arrange games

Tupelo.application do |app|
  app.start_monitor if VERBOSE

  app.local do |client|
    client.write token
  end
  
  N_PLAYERS.times do
    app.child do |client|
      me = client.client_id

      client.take token # bottleneck and fragile until 'client.write token'
      other_player = client.read_nowait(name: nil)
        # sleep 1 # program takes ~N_PLAYERS sec to finish

      if other_player
        client.take other_player
        client.write(
          player1: me,
          player2: other_player["name"])
        client.write token
        you = other_player["name"]

      else
        client.write(name: me)
        client.write token
        game = client.read(
          player1: nil,
          player2: me)
        you = game["player1"]
      end

      client.log "now playing with #{you}"
    end
  end
end
