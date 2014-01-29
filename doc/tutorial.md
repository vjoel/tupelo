Tutorial
========

Let's take a quick walk-through of tupelo.

Interactive shell: one client
-----------------------------

To start, let's ignore the distributed nature of tupelo and just work with a single client session in a shell. Try running tup:

      $ tup
      >> w ["hello", "world"]
      >> ra
      => [["hello", "world"]]
      >> t [nil, nil]
      => ["hello", "world"]

The `help` command will print out some basic documentation on the tup shell, such as the aliases used above.

**Write** one or more tuples (and wait for the transaction to be recorded in the local space):

      w <tuple>,...
      write_wait <tuple>,...

Write without waiting:

      write <tuple>,...

Write and then wait, under user control:

      write(...).wait

Pulse a tuple or several (write but immediately delete it, like pubsub):

      pl <tuple>,...
      pulse_wait ...

Pulse without waiting:

      pulse_nowait <tuple>,...

Read tuple matching a template, waiting for a match to exist:

      r <template>
      read <template>
      read_wait <template>

Read tuple matching a template and return it, without waiting for a match to exist (returning nil in that case):

      read_nowait <template>

Note that neither #read nor #read_nowait wait for any previously issued writes to complete. The difference is that #read waits for a match to exist and #read_nowait does not. Compare:

      write [1]; read_nowait [1]        # ==> nil, probably
      write [2]; read [2]               # ==> [2]

Read all tuples matching a template, no waiting (like #read_nowait):

      ra <template>
      read_all <template>

If the template is omitted, reads everything (careful, you get what you ask for!). The template can be a standard template as discussed below or anything with a #=== method. Hence

      ra Hash

reads all hash tuples (and ignores array tuples), and

      ra proc {|t| t.size==2}

reads all 2-tuples.

Read tuples in a stream, both existing and as they arrive:

      read <template> do |tuple| ... end
      read do |tuple| ... end             # match any tuple

Take a tuple matching a template:

      t <template>
      take <template>

Take a tuple matching a template and optimistically use the local value before the transaction is complete:

      x_final = take <template> do |x_optimistic|
        ...
      end

There is no guarantee that `x_final == x_optimistic`. The block may execute more than once. (This is a kind of speculative execution.)

Take a tuple matching a template, but only if a local match exists (otherwise return nil):

      take_nowait <template>

      x_final = take_nowait <template> do |x_optimistic|
        ...
      end

Note that a local match is still not a guarantee of `x_final == x_optimistic`. Another process may take `x_optimistic` first, and the take will be re-executed. (Think of #take_nowait as a way of saying "take a match, but don't bother trying if there is no match known at this time.") Similarly, #take_nowait returning nil is not a guarantee that a match does not exist: another process could have written a match later than the time of the local search.

Perform a general transaction:

      result =
        transaction do |t|
          rval = t.read ... # optimistic value
          t.write ...
          t.pulse ...
          tval = t.take ... # optimistic value
          [rval, tval]      # pass out result
        end

Note that the block may execute more than once, if there is competition for the tuples that you are trying to #take or #read. When the block exits, however, the transaction is final and universally accepted by all clients.

Tuples written or taken during a transaction affect subsequent operations in the transaction without modifying the tuplespace or affecting other concurrent transactions (until the transaction completes):

      transaction do |t|
        t.write [3]
        p t.read [3] # => 3
        p read_all   # => [] # note read_all called on client, not trans.
        t.take [3]
        p t.read_nowait [3] # => nil
      end

Be careful about context within the do...end. If you omit the `|t|` block argument, then all operations are automatically scoped to the transaction, rather than the client. The following is equivalent to the previous example:

      client = self # local var that we can use inside the block
      transaction do
        write [3]
        p read [3]
        p client.read_all
        take [3]
        p read_nowait [3]
      end

You can timeout a transaction:

      transaction timeout: 1 do
        read ["does not exist"]
      end

This uses tupelo's internal lightweight scheduler, rather than ruby's heavyweight (one thread per timeout) Timeout, though the latter works with tupelo as well.

You can also abort a transaction while inside it by calling `#abort` on it:

      write [1]
      transaction {take [1]; abort}
      read_all # => [[1]]

Another thread can abort a transaction in progress (to the extent possible) by calling `#cancel` on it. See [example/cancel.rb](example/cancel.rb).

Interactive shell: two clients
------------------------------

Run tup with a server file so that two sessions can interact. Do this in two terminals in the same dir:

      $ tup sv

(The 'sv' argument names a file that the first instance of tup uses to store information like socket addresses and the second instance uses to connect. The first instance starts the servers as child processes. However, both instances appear in the terminal as interactive shells.)

To do this on two hosts, copy the sv file and, if necessary, edit its connect_host field. You can even do this:

      host1$ tup sv tcp localhost

      host2$ tup host1:path/to/sv --tunnel


The Example directory
---------------------

Look at the examples. If you installed tupelo as a gem, you may need to dig a bit to find the gem installation. For example:

      ls -d /usr/local/lib/ruby/gems/*/gems/tupelo*

Note that all bin and example programs accept blob type (e.g., --msgpack, --json) on command line (it only needs to be specified for server -- the clients discover it). Also, all these programs accept log level on command line. The default is --warn. The --info level is a good way to get an idea of what is happening, without the verbosity of --debug.

Tracing and debugging
---------------------

In addition to the --info switch on all bin and example programs, bin/tspy is also really useful; it shows all tuplespace events in sequence that they occur. For example, run

      $ tspy sv

in another terminal after running `tup sv`. The output shows the clock tick, sending client, operation, and operation status (success or failure).

There is also the similar --trace switch that is available to all bin and example programs. This turns on diagnostic output for each transaction. For example:

      tick    cid status operation
         1      2        write ["x", 1]
         2      2        write ["y", 2]
         3      3        take ["x", 1], ["y", 2]

The `Tupelo.application` command, provided by `tupelo/app`, is the source of all these options and is available to your programs. It's a kind of lightweight process deployment and control framework; however `Tupelo.application` is not necessary to use tupelo.

