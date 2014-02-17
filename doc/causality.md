Causality, clocks, and consistency in tupelo
=====================================

The causality relation is the cause-effect relation between events 
http://en.wikipedia.org/wiki/Causality. We care about causality in programs because we need it to understand their behavior. It's especially important in distributed programming, with network delays and asynchronous communication.

Tupelo does not need a scheme as complex as vector clocks http://en.wikipedia.org/wiki/Vector_clock because all transactions go through a sequencer, forcing them in to a linear order. In fact, the position in that sequence ('global tick') is really the only clock that matters in tupelo; wall clocks are not used in the distributed protocol (though they can of course be use locally by clients).

preservation guarantees

It's important, for any distributed programming framework, to understand what is guaranteed about 

Before we start with the examples in tupelo, let's define a method to "clear the blackboard" before each example (our examples will only use tuples that are arrays of length 1, for simplicity):

    def cb
      while take_nowait([nil]); end
    end

and a method to "read the blackboard":

    def rb
      read_all [nil]
    end

You may also find it useful to turn on tracing in tup:

    >> trace
      tick    cid status operation
    => true
    >> w [1]; w [2]
         1      1        write [1]
         2      1        write [2]
    => <Tupelo::Client::Transaction done at global_tick: 2 write [2]

A quick example:

    cb; write [1]; write [2]

These two transactions (let's not count the `cb` event) are prepared in order by the tupelo client (they also execute in the same order by tupelo worker threads on all receiving clients. Compare:

    cb; write [1]; x,_ = read [nil]; write [x+1]

The same remarks apply. In both cases the `write [1]` event happens before the `write [2]` event. But in the second case the program has an explicit causal link between the two events: the second integer is the increment of the first. Since this kind of causal link can be hard to detect (even for the programmer!), we use the happens-before relation as a surrogate. The happens-before relation (http://en.wikipedia.org/wiki/Happened-before) is a superset of the causality relation: if A causes B then A happens before B. If our system preserves happens-before in some situation, then it also preserves causality in that situation.


causality is tracked both within a sequential system (a thread, say) and across communication channels and nodes. In fact, thats what's happening above: transactions are prepared on the client, committed to the sequencer, and bounced back to the client to execute (possibly failing). 
This can lead to event orderings that are not linear. For example, there is a diamond pattern in the events we have been looking at:


table
A
B
C
D

### use trace command


is this correct, in terms of causality
  write_nowait [1]; read_all # => []
  write_nowait [2]; transaction {read_nowait [2]} # => nil

but
  t = transaction; t.write [5]; t.commit; transaction {read [5]}
    # => [5]
  write x: 0; transaction {take x: 0; write x: 1}; transaction {read x: nil}
    # => {"x"=>1}
  write x: 0; t = transaction; t.take x: 0; t.write x: 1; t.commit;
    transaction {read x: nil}
    # => {"x"=>1}
  write x: 0; t = transaction; t.take x: 0; t.write x: 1; t.commit;
    p read_all x: nil; # => [{"x"=>0}]
    transaction {read x: nil} # => {"x"=>1}

and
  >> clear; write [1]; write [2]; write [3]; write [4]; read_all
  => [] # YMMV
  >> clear; write [1]; write [2]; write_wait [3]; write [4]; read_all
  => [[1], [2], [3]]

*** causality is preserved in exec timeline (consistent, global linear sequence), not prep time (best effort)
