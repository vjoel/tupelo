== Riemann example

A toy implementation of Riemann (http://riemann.io).

Manages streams of events, storing them in a tuplespace and expiring them as specified. In different client processes, the tuplespace is stored in several different data structures, depending on needs.

Each version of this example adds progressively more features and efficiency. See comments in each riemann.rb for details.

=== Files

* common files, used in all versions

  * [event-subspace.rb](event-subspace.rb): defines which tuples are events
  
  * [producer.rb](methods to generate tuples and write them from a tupelo
    client)

* v1

* v2
