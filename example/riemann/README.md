== Riemann example

A toy implementation of Riemann (http://riemann.io).

Manages streams of events, storing them in a tuplespace and expiring them as specified. The tuplespace is replicated among several client processes. In different clients, the tuplespace is stored in different data structures, depending on needs, including hash, rbtree, and sqlite.

Each version of this example adds progressively more features and efficiency. See comments in each riemann.rb for details.

=== Files

* common files, used in all versions

  * [event-subspace.rb](event-subspace.rb): defines which tuples are events
  
  * [producer.rb](producer.rb): methods to generate tuples and write them
    from a tupelo client

* [v1/](v1)

* [v2/](v2)
