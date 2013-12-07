# The underlying messaging protocol, funl, keeps track of a unique id per
# message. This id is awailable in the transaction object, but only after
# commit has succeeded. We can get the id from the transaction object and
# use it as a globally unique id.
#
# Another source of unique ids is the client id, which is unique per client.
# You can get an id that is uniq per message by combining it with any value
# that is unique, in that client, to the message, such as a counter.
# This has the advantage of not requiring a transaction.

require 'tupelo/app'

Tupelo.application do
  local do
    tr = pulse_wait ["noop"] # returns transaction
    uniq_id = tr.global_tick # available after transaction commits
    log "unique id is #{uniq_id}"

    # now, we can use that unique id in some other tuples
    write foo: "bar", id: uniq_id
    log take foo: nil, id: nil
    
    @counter = 0
    next_local_id = proc { @counter+=1 }
      # Protect this with a mutex or queue if other threads need it, or
      # use the atomic gem.

    cid = client_id
    
    uniq_id2 = [next_local_id.call, cid]
    write foo: "baz", id: uniq_id2
    log take foo: nil, id: nil
  end
end
