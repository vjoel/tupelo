FAQ about tupelo
---

Utility
=======

1. What is tupelo not good for?

  - high availability, very large scale systems
  
  - high volume stream data (for low volume stream data, see [chat](example/chat/chat.rb))
  
  - applications that cannot accept a SPoF (though in the future, "SPoF" may be
    reduced to simply a "bottleneck" by replicating the message sequencer)

2. What is tupelo good for? What are the "use cases"?

  - read scaling out (redundant array of sqlite example)
  
  - process coordination of complex background job
  
  - lightweight coordination: when you need task queues or other mechanisms
    and you don't want to run a standalone queue server

3. Is tupelo a database?

  No. It's really more of a middleware. Tupelo doesn't have its own disk storage, indexing, queries, etc. It depends on other programs to provide these. That's actually a strength, since you can use different storage backends for different cases (subspaces, for example).

4. What's really new about tupelo?

  Tupelo combines these ideas:

  - Atomic broadcast/multicast, virtual synchrony

  - Tuplespace operation semantics (write, read, take)

  - Transactions

  All of these are old ideas, but the three together is possibly new.


Tuplespace Operations and Transactions
======================================

1.  Why no update operation?

  Tuples are immutable while in the space. However, you can update by doing #take and #write in a transaction:
    
        transaction do
          _, n = take ["my counter", Integer]
          write ["my counter", n+1]
        end

  Some storage providers may detect this take-write and perform a more efficient update instead.

Debugging
=========

1. How can I see what tuples a client is getting?

Use --trace or #notify or just add this thread:

    Thread.new do
      read {|tt| log tt}
    end

and if you want pass a template to #read.

Tuplets
=======


General
=======

1. Why "tupelo"?

    Resonance with "tuple", I guess... Also, I'm a fan of Uncle Tupelo.

2. 
