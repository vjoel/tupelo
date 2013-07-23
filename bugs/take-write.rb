require 'tupelo/app'

Tupelo.application do |app|
  app.local do |client|
    client.write_wait [1]

    note = client.notifier

    client.transaction do |t|
      x = t.take [1]
      t.write x
    end
    
    note.wait
    status, tick, cid, op = note.wait
    p op # should "read [1]", not "write [1]; take [1]"
    # this is just an optimization, not really a bug
  end
end
