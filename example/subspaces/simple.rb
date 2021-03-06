# Minimal example of using subspaces to limit which tuples each client sees.
# Run with --trace to see assignment to subspaces.

require 'tupelo/app'

Tupelo.application do
  local do
    log.progname = "before"
    log [subscribed_all, subscribed_tags]

    define_subspace "foo", [Numeric]

    log read_all(Object)
  end
  
  child subscribe: [], passive: true do
    log.progname = "not a subscriber"
    log "should never see this: #{read(subspace "foo")}"
  end
  
  cid = child subscribe: ["foo"] do
    log.progname = "foo subscriber"
    log [subscribed_all, subscribed_tags]
    write [1]
    write_wait ["abc"]
    log read_all(Object)
  end
  Process.wait cid

  local do
    log.progname = "after"
    log [subscribed_all, subscribed_tags]
    log read_all(Object)
    log read_all(subspace "foo")
  end
end
