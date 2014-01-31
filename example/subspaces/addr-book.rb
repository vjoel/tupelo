# Example of attaching a data structure to a subspace. In this case, we
# use an in-memory structure, a red-black tree, to maintain the tuples in
# sorted order. (For a simpler example, with a hash instead of a tree,
# see [memo example using subspaces](../multi-tier/memo2.rb). The process(es)
# that manages the rbtree needs to subscribe to this subspace, so it can
# apply writes to the rbtree.
#
# We also have subspaces for query commands and responses so that other clients
# can access the sorted structure. The process(es) that host the rbtree also
# subscribe to the command subspace (and write to, but not subscribe to, the
# response subspace.) The process that query
# do so by writing to the command subspace and subscribing to the response
# subspace.
#
# This is kinda like redis, but the data is distributed, not stored on the same
# process that is managing concurrency. Multiple replicas increase concurrency.
# Run this example with --show-handlers to see which replicas are responding.
#
# Note that a subspace can be sharded to different clients, and different
# clients can each use their own data structure for these tuples.

require 'tupelo/app'
require_relative 'sorted-set-space'

SHOW_HANDLERS = ARGV.delete("--show-handlers")

N_REPLICAS = 3

ab_tag = "my address book"
cmd_tag = "#{ab_tag} commands"
resp_tag = "#{ab_tag} responses"

Tupelo.application do
  local do
    use_subspaces!

    # Subspace for tuples belonging to the addr book.
    define_subspace(ab_tag, [
      ab_tag,
      String,   # name
      nil       # address; can be any object
    ])
    
    # Subspace for commands for fetch, delete, first, last, prev, next.
    # We can't use #read and #take for fetch and delete because then the
    # requesting client would have to subscribe to the ab_tag subspace.
    define_subspace(cmd_tag, [
      cmd_tag,
      nil,      # request id, such as [client_id, uniq_id]
      String,   # cmd name
      Array     # arguments
    ])

    # Subspace for responses to commands. A response identifies the command
    # it is responding to in two ways: by copying it and by an id. The
    # former is so that another client can "spy" on one client's query
    # responses, perhaps saving effort. The latter is to distinguish between
    # iterations of the same command (first, first, ...).
    define_subspace(resp_tag, [
      resp_tag,
      nil,      # in response to this request id
      String,   # cmd name
      Array,    # arguments
      nil,      # result of query -- type depends on command
    ])
  end

  N_REPLICAS.times do |i|
    # Inserts are just writes, which are handled by Worker and SortedSetSpace,
    # so this child's app loop only needs to handle the special commands.
    child tuplespace: [SortedSetSpace, ab_tag],
          subscribe: [ab_tag, cmd_tag], passive: true do

      log.progname = "replica ##{i}"

      loop do
        _, rqid, cmd, args = take(subspace cmd_tag)
        if SHOW_HANDLERS
          log "handling request for #{cmd} #{args}"
        end

        case cmd
        when "delete"                # handled by one replica
          args.each do |name|
            take [ab_tag, name, nil] # propagates to all replicas
          end

        when "fetch"
          _, _, addr = read_nowait [ab_tag, args[0], nil] # addr might be nil
          write [resp_tag, rqid, cmd, args, addr]

        when "next", "prev", "first", "last"
          _, name, addr = read_nowait SortedSetTemplate[ab_tag, cmd, *args]
          write [resp_tag, rqid, cmd, args, [name, addr]]

        else # maybe write an error message in a tuple
          log.error "bad command: #{cmd}"
        end
      end
    end
  end
  
  child subscribe: resp_tag do
    log.progname = "user agent"

    counter = 0 # this is a bit hacky -- could use prev txn's global tick
    next_rqid = proc { [client_id, counter+=1] }
      # Protect this with a mutex if other threads need it.

    # write some ab entries
    write [ab_tag, "Eliza", "100 E St."]
    write [ab_tag, "Alice", "100 A St."]
    write [ab_tag, "Daisy", "100 D St."]
    write [ab_tag, "Bob", "100 B St."]
    write [ab_tag, "Charles", "100 C St."]

    # make some queries
    rqid = next_rqid.call
    name = "Daisy"
    write [cmd_tag, rqid, "fetch", [name]]
    addr = take( [resp_tag, rqid, nil, nil, nil] ).last
    log "Looked up #{name} and found: #{name} => #{addr}"
    
    rqid = next_rqid.call
    write [cmd_tag, rqid, "first", []]
    name, addr = take( [resp_tag, rqid, nil, nil, nil] ).last
    log "first entry: #{name} => #{addr}"
    
    5.times do
      rqid = next_rqid.call
      write [cmd_tag, rqid, "next", [name]]
      name, addr = take( [resp_tag, rqid, nil, nil, nil] ).last
      log( name ? "next entry: #{name} => #{addr}" : "no more entries" )
    end
  end
end
