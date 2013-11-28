# The #take and #take_nowait methods behave the same if a match is found in
# the local tuple store: they both send a transaction that takes the tuple.
# If no match is found, #take blocks, but #take_nowait returns nil.
#
# In a transaction, #take_nowait has the same behavior. But keep in mind that
# things may change by the time the transaction commit is successful.
# Some other process may write a matching tuple. So, the return value of
# nil is not a guarantee that, when the transaction finishes, there is no match.
# This example demonstrates this point.
#
# See these examples for interesting uses of #take_nowait in a transaction:
#
# broker-optimistic.rb
# broker-optimistic-v2.rb
# lease.rb
# pregel/distributed.rb

require 'tupelo/app'

Tupelo.application do
  child do
    results = transaction do
      r1 = take_nowait [1]
      sleep 1
      r2 = take_nowait [2]
      [r1, r2]
    end
    
    log results
  end

  child do
    sleep 0.5
    write [1], [2]
  end
end
