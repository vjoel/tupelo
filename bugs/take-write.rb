require 'tupelo/app'

Tupelo.application do
  local do
    write_wait [1]

    note = notifier

    transaction do
      x = take [1]
      write x
    end
    
    note.wait
    status, tick, cid, op = note.wait
    p op # should "read [1]", not "write [1]; take [1]"
    # this is just an optimization, not really a bug

    # however, need to be careful about this optimization, since
    #   transaction {take [1]; take [1]; write [1]}
    # is not the same as
    #   transaction {take [1]; read [1]}
    # but rather more like
    #   transaction {take [1]; read_distinct [1]}
    # except #read_distinct is not defined.
  end
end
