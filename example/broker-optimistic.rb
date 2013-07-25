# The local control flow in this example is more complex than in
# broker-locking.rb, but it has far fewer bottlenecks (try inserting some sleep
# 1 calls), and it is not possible for a token to be lost (leaving the lock in a
# locked state) if a process dies.

require 'tupelo/app'

N_PLAYERS = 10

Tupelo.application do |app|
  N_PLAYERS.times do
    app.child do |client|
      me = client.client_id
      client.write name: me
      you = nil
      
      1.times do
        begin
          t = client.transaction
          if t.take_nowait name: me
            you = t.take(name: nil)["name"]
            t.write(
              player1: me,
              player2: you)
            t.commit.wait
            break
          else
            t.cancel
          end
        rescue Tupelo::Client::TransactionFailure => ex
        end
          
        game = client.read_nowait(
          player1: nil,
          player2: me)
        redo unless game
        you = game["player1"]
      end

      client.log "now playing with #{you}"
    end
  end
end
