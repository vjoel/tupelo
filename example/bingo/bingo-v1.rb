require 'tupelo/app'

N_BUYERS = 3
MAX_PER_BUYER = 4

Tupelo.application do
  child do
    # stock up on cards to sell
    10.times do |i|
      write ["card", i] # todo add card details
    end
    
    # start selling
    write ["selling", true]
    sleep 1
    
    # stop selling
    take ["selling", true]
    write ["selling", false]

    # run the game
    p read_all ["player", nil, "card", nil]
  end

  N_BUYERS.times do
    child do
      catch :done_buying do
        MAX_PER_BUYER.times do
          transaction do
            _, selling = read ["selling", nil]
            if selling
              _, card_id = take ["card", nil]
              write ["player", client_id, "card", card_id]
            else
              throw :done_buying
            end
          end
        end
      end
    end
  end
end
