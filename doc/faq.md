FAQ about tupelo
---

Utility
=======

1. What is tupelo not good for?

  - high availability, very large scale systems
  
  - high volume stream data. For low volume stream data, see [chat](example/chat/chat.rb). For using tupelo to coordinate access to high volume data, see [socket-broker.rb](example/socket-broker.rb).
  
  - applications that cannot accept a SPoF (though in the future, "SPoF" may be
    reduced to simply a "bottleneck" by replicating the message sequencer)

2. What is tupelo good for? What are the "use cases"?

  - read scaling out (redundant array of sqlite example)
  
  - process coordination of complex background job; dataflow more complex than map-reduce
  
  - lightweight coordination: when you need task queues or other mechanisms
    and you don't want to run a standalone queue server

3. Is tupelo a database?

  No. It's really more of a middleware. Tupelo doesn't have its own disk storage, indexing, queries, etc. It depends on other programs to provide these. That's actually a strength, since you can use different storage backends for different cases (subspaces, for example). Furthermore, those backends are not just storage, but unlimited processing in potentially any language that can talk the msgpack-based tupelo protocol.

4. Is tupelo a web framework or application?

  No. But see the [web examples](example/multi-tier).
  Also, tuple space has some similarities to REST: the emphasis on objects with few verbs, and constraints on the meaning of those verbs.

5. What's really new about tupelo?

  Tupelo combines these ideas:

  - Atomic broadcast/multicast, virtual synchrony

  - Tuplespace operation semantics (write, read, take)

  - Transactions

  All of these are old ideas, but putting the three together is possibly new.


Tuplespace Operations and Transactions
======================================

1. Why no update operation?

  Tuples are immutable while in the space. However, you can update by doing #take and #write in a transaction:
    
        transaction do
          _, n = take ["my counter", Integer]
          write ["my counter", n+1]
        end

  Some storage providers may detect this take-write and perform a more efficient update instead.

2. What kind of clocks does tupelo use?

  Tupelo does not use wall clocks for any distributed coordination. The only use of wall clock time is purely client-side, to manage client-requested transaction timeouts. Transactions are linearly ordered by a "tick" counter in the message sequencer.

3. Are transactions concurrent? What's happening in parallel?

  Let's break this into two cases: _preparing_ transactions (before attempting to commit) and _executing_ transactions (which determines whether the commit succeeds).

  During the _prepare_ phase, each transaction is a separate sequence of events (calls to #read, #write, #take et al) that executes concurrently with other transactions. There is no synchronization between two concurrent transactions in in this stage. For example:

      $ tup
      >> t1 = transaction
      => Tupelo::Client::Transaction open 
      >> t2 = transaction
      => Tupelo::Client::Transaction open 
      >> w [1], [2], [3]
      => Tupelo::Client::Transaction done at global_tick: 1 write [1], [2], [3]
      >> t1.read [1]
      => [1]
      >> t2.read [2]
      => [2]
      >> t1.take [3]
      => [3]
      >> t2.take [3]
      => [3]
      >> t1.commit.value
      => [[3]]
      >> t2
      => Tupelo::Client::Transaction failed take RubyObjectTemplate: [3] read RubyObjectTemplate: [2] missing: [[3]]

  Before the `t1.commit`, there is no synchronization.

  Typically, there is one transaction at a time per thread, unlike in the above example. Tupelo supports multiple client threads per process. The client threads interact with a single worker thread that manages the local subspaces and the communication with the message sequencer.

  After #commit, the transaction executes on all clients that subscribe to the affected subspaces, resulting (deterministically, the same for all clients) in either success or failure. These executions are performed by the worker thread in each client in (deterministic) linear order based on the tick. In this phase, there is no synchronization among proceses or threads, except that, within a process, a client thread that is waiting for a template match (#read or #take) will be notified by the worker thread when the match arrives (or immediately if the match already exists). For example:

      >> Thread.new { read {|x| puts "Got #{x}"} }
      => #<Thread:0x007f677b93f258 run>
      >> write ["some", "tuple"]
      Got ["some", "tuple"]

  The lack of many points of synchronization means that client threads run mostly in parallel, if the language/hardware permit, and separate client processes are completely parallel except for waiting for template matches.

4. How do transactions fail?

  two failure modes, rollback, retry, block syntax


Performance
===========

1. What factors determine the latency of a request?

  A #read is always local (no network hops). A Transaction#commit generally requires one round-trip to the message sequencer (two network hops).

2. How can I reduce latency?

  Use #write (same as #write_nowait) instead of #write_wait. The usual warnings for un-acked writes apply, but if some later write or other transaction succeeds, then the previous one did.

  Optimistically use results of #take within a transaction. For example, rather than this:

      >> Thread.new do
           op = take ["multiply", Numeric, Numeric]
           write ["result", op[1]*op[2]]
         end
      => #<Thread:0x007fc2300af448 run>
      >> write ["multiply", 3, 4]
      => Tupelo::Client::Transaction closed write ["multiply", 3, 4]
      >> read ["result", nil]
      => ["result", 12]

  you could wrap the take-compute-write in a transaction:

      $ tup
      >> Thread.new do
           transaction do
             op = take ["multiply", Numeric, Numeric]
             write ["result", op[1]*op[2]]
           end
         end
      => #<Thread:0x007f5500a32c88 run>
      >> write ["multiply", 3, 4]
      => Tupelo::Client::Transaction closed write ["multiply", 3, 4]
      >> read ["result", nil]
      => ["result", 12]

  Note that the #take value is used immediately (as soon as the value is available in local storage), before the transaction has even executed. If some other process concurrently takes that same tuple, then this transaction will roll back and attempt again to take a matching tuple.
  The latency of the transaction is less than that of the two operations separately: two hops rather than four hops. The more expensive the calculation, of course, the more (clock) time is spent inside the transaction, which increases the chance that there will be contention for that tuple. You can run a tspy process to see the sequence of messages.
  Another advantage of the transaction is that it is atomic, so a network failure or hardware failure in the client between the #take and the #write will not cause the tuple to be lost, as it would in the first case.


Apps, Tools, Command-line Interface
===================================

1. Why is there no CLI for a single transaction or operation, like maybe `tup ... "read [...]"`?

  This would only make sense for write and pulse ops, not read or take. The
reason is that #read and #take depend on the client being subscribed to the subspace to which the ops apply. Subscribing may involve significant data transfer, depending on the size of the subspace. It is not generally efficient to do this for a single operation. Use bin/tup instead.

Networking: Security, Firewalls, Hostnames
======================

1. How can I run tupelo securely over a public network?

  The built-in security mechanism for tupelo is based on ssh for process control and ssh tunnels for data sockets. OpenSSH 6.0 or later is recommended (tupelo has workarounds for earlier versions). Details of the implementation are in the [easy-serve library](https://github.com/vjoel/easy-serve).

  But first, if you are working within a single host, just use UNIX sockets, so you can use UNIX permissions to control access within the host and don't have to worry about access from outside the host. The Tupelo.application framework defaults to UNIX sockets in a tmpdir. You can also explicitly request them from the command line for any program based on the framework, such as bin/tup. For example:

      $ tup srv unix /path/to/sock
      
      $ tup srv

  If you need TCP networking but want to minimize exposure, you can request that tupelo listen only on localhost:

      $ tup srv tcp localhost

  Then, you can connect from other hosts _only_ using ssh tunnels:

      $ tup myhost:path/to/srv --tunnel

  Here, myhost is whatever you need to ssh into the first host (it might be username@example.com). The services file at path/to/srv is read using ssh (it doesn't have to be on the same host as the services themselves, but usually is). Then tunnels to those services are set up over the ssh connection. This is client-managed tunneling.

  The procedure for server-managed tunneling is different. When a main Tupelo.application process needs to start a remote client that tunnels back to the server, simply pass `tunnel: true` to the #remote call. (In fact, if you pass --tunnel on the command line, the `true` value becomes the default for all #remote clients.) For [example](example/map-reduce/remote-map-reduce.rb).

2. How can I connect clients across private subnets and behind firewalls?

  The built-in solution in tupelo is to use ssh tunnels. If the services in the services file are accessible from a host (via tunnels, if necessary), then a tupelo client on that host can share data with other clients (it's a star topology).

3. How should I configure ssh?

  Using remotes and tunnels is much easier if you configure ssh to use control sockets to multiplex ssh sessions over a single connection per host pair. The following works well in .ssh/config:

      Host *
        ControlMaster auto
        ControlPath ~/tmp/.ssh/%r@%h:%p
        ControlPersist yes

  Note that the dir `~/tmp/.ssh` must exist, so if ~/tmp is periodically cleaned, you might want to create it in your .profile / .bashrc / .zshrc file. You can  also install public ssh keys to avoid typing your password on first connection.


Debugging
=========

1. How can I see what tuples a client is getting?

  Use --trace or #notify or just add this thread:

      Thread.new do
        read {|tt| log tt}
      end

  Optionally, pass a template to #read.


Tuplets
=======


General
=======

1. Why "tupelo"?

  Resonance with "tuple", I guess... Also, I'm a fan of Uncle Tupelo.
