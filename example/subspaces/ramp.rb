# Read-atomic multipartition transactions, as per:
#   http://www.youtube.com/watch?v=_rAdJkAbGls (around minutes 28-30)
#   http://www.bailis.org/blog/non-blocking-transactional-atomicity
#   http://www.bailis.org/blog/scalable-atomic-visibility-with-ramp-transactions
#
# Example of transacting separately on two subspaces (i.e. shardable subsets of
# the tuplespace), but hiding intermediate tuples so that the results show up
# atomically when readers look for them. (Note that this is different from
# atomically transacting on replicas of the same shard, which is inherent in
# tupelo transactions.)
#
# In tupelo, we could use the classic tuplespace technique of taking a lock
# tuple to protect the sequence of two transactions on the two subspaces, but
# that would reduce concurrency and require a lease mechanism in case the lock
# holder dies. That's possible, but not scalable. So we use transactions with a
# trick...
#
# Tupelo doesn't allow transactions to cross subspace boundaries (except in the
# special case of writes outside of a subspace--see
# [doc/subspace.md](doc/subspace.md)). We can get around this at the application
# level, with a few extra steps. This adds latency, but preserves effective
# atomicity from the application's point of view and does not introduce any
# fragile locks or blocking. The main trick (as in Bailis's talk) is to use a
# globally unique value -- in his talk he used a transaction id. We could use
# the global_tick of a successful transaction (same idea) or a unique id based
# on client_id -- see [example/uniq-id.rb](example/uniq-id.rb).

# todo: use a smarter data structure for the x and y subspaces

require 'tupelo/app'

N_ITER = 6
X_REPLICATIONS = 1 # number of copies of the shard of X data
Y_REPLICATIONS = 1 # number of copies of the shard of Y data

def next_local_id
  @counter ||= 0
  @counter += 1
    # Protect this with a mutex or queue if other threads need it, or
    # use the atomic gem. It's ok in a multiprocess app without mutex,
    # because each process has its own copy.
end

Tupelo.application do

  local do
    bool = PortableObjectTemplate::BOOLEAN
    
    define_subspace("x", {
      x:      Numeric,  # data payload
      id:     Array,    # [client_id, local_id]
      final:  bool      # false means pending
    })
    
    define_subspace("y", {
      y:      Numeric,  # data payload
      id:     Array,    # [client_id, local_id]
      final:  bool      # false means pending
    })

    define_subspace("ack", { # could make this per-client
      ack:    String,   # state ack-ed: "pending"
      id:     Array     # [client_id, local_id]
    })
  end

  X_REPLICATIONS.times do |xi|
    child subscribe: ["x"], passive: true do
      log.progname = "x#{xi}"

      read x: nil, id: nil, final: nil do |t|
        log t
        if t["final"]
          # co-writes are at least pending at this point in global time
          # ("stable"), so remove pending tuple when final tuple exists.
          # First responding replica wins, and the take propagates to others.
          take_nowait t.merge(final: false)
        else
          write ack: "pending", id: t["id"]
        end
      end
    end
  end

  Y_REPLICATIONS.times do |yi|
    child subscribe: ["y"], passive: true do
      log.progname = "y#{yi}"

      read y: nil, id: nil, final: nil do |t|
        log t
        if t["final"]
          # co-writes are at least pending at this point in global time
          # ("stable"), so remove pending tuple when final tuple exists.
          # First responding replica wins, and the take propagates to others.
          take_nowait t.merge(final: false)
        else
          write ack: "pending", id: t["id"]
        end
      end
    end
  end

  child subscribe: ["ack"] do
    # Does not subscribe to x or y, so can only write to those spaces.
    log.progname = "writer"
    
    N_ITER.times do |i|
      uniq_id = [client_id, next_local_id]

      x = {x: i, id: uniq_id}
      y = {y: i, id: uniq_id}

      write x.merge(final: false), y.merge(final: false) # pending
      (X_REPLICATIONS + Y_REPLICATIONS).times do
        take ack: "pending", id: uniq_id  # wait for one to be pending
      end
      write x.merge(final: true), y.merge(final: true)

      # Note that each of the two above writes is a multi-space transaction
      # which is allowed because it is purely writes (no reads or takes).
      # However, this only guarantees read atomicity for tupelo clients (because
      # of the global transaction ordering). If some processes are accessing the
      # x and y data stores through protocols other than tupelo (such as sql
      # over sockets), this is not enough--they could see inconsistent state.
      # Hence the explicit wait for an ack to truly synchronize the state.
    end
  end

  # This doesn't test that RAMP is working -- it will always see a consistent
  # view because of tupelo, even without the pending/ack trick. It is more
  # informative to look at the log output from the x and y clients.
  #
  # The key point of this example is that we could write a reader process that
  # doesn't use tupelo at all, but accesses the data stores directly (assuming
  # we're using a client-server store like postgres or a concurrent key-value
  # store like leveldb or lmdb). This non-tupelo process would only need to be
  # aware of the RAMP semantics of pending and id fields.
  child subscribe: ["x", "y"], passive: true do
    log.progname = "reader"
    read do |t|
      log t
    end
  end
end
