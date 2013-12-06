# The underlying messaging protocol, funl, keeps track of a unique id per
# message. This id is awailable in the transaction object, but only after
# commit has succeeded. We can get the id from the transaction object and
# use it as a globally unique id.

require 'tupelo/app'

Tupelo.application do
  local do
    tr = pulse_wait ["noop"] # returns transaction
    uniq_id = tr.global_tick # available after transaction commits
    log "unique id is #{uniq_id}"

    # now, we can use that unique id in some other tuples
    write foo: "bar", id: uniq_id
    log take foo: nil, id: nil
  end
end
