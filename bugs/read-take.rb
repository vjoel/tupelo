require 'tupelo/app'

Tupelo.application do
  local do
    write_wait [1]

    note = notifier

    transaction do 
      read [1]
      take [1]
    end
    
    note.wait
    status, tick, cid, op = note.wait
    p op # should "take [1]", not "take [1]; read [1]"
    # this is just an optimization, not really a bug
  end
end
