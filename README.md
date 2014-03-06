Tupelo
==

A tuplespace that is fast, scalable, and language agnostic. Tupelo is designed for distribution of both computation and storage (disk and memory), in a unified language that has both transactional and tuple-operation (read/write/take) semantics.

This is the reference implementation in ruby. It should be able to communicate with implementations in other languages.

Documentation
============

* [Tutorial](doc/tutorial.md)
* [FAQ](doc/faq.md)
* [Comparisons](doc/compare.md)
* [Transactions](doc/transactions.md)
* [Replication](doc/replication.md)
* [Subspaces](doc/subspace.md)
* [Causality](doc/causality.md)
* [Concurrency](doc/concurrency.md)
* [Examples](example/)

Internals
---------
* [Architecture](doc/arch.md)
* [Protocols](doc/protocol.md)

Talk
----
* [Abstract](sfdc.md) and [slides](doc/sfdc.pdf) for San Francisco Distributed Computing meetup

Getting started
==========

1. Install ruby 2.0 or 2.1 (not 1.9) from http://ruby-lang.org. Examples and tests will not work on windows (they use fork and unix sockets) or jruby, though probably the underying libs will (using tcp sockets).

2. Install the gem and its dependencies (you may need to `sudo` this):

        gem install tupelo

3. Try running tup:

        $ tup
        >> w ["hello", "world"]
        >> ra
        => [["hello", "world"]]
        >> t [nil, nil]
        => ["hello", "world"]

4. Take a look at the [FAQ](doc/faq.md), [tutorial](doc/tutorial.md), and the many [examples](example/).


Applications
=======

Tupelo is a flexible base layer for various distributed programming paradigms: job queues, dataflow, map-reduce, etc. Using subspaces, it's also a transactional, replicated datastore with pluggable storage providers.


Advantages
==========

Tupelo can be used to impose a unified transactional structure and distributed access model on a mixture of programs and stores. ("Polyglot persistence".) Need examples....

Speed (latency, throughput):

* minimal system-wide bottlenecks

* non-blocking socket reads

* read -- local and hence very fast

* write -- fast, pipelined (waiting for acknowledgement is optional);  

* transactions -- combine several takes and writes, reducing latency and avoiding locking

Can use optimal data structure for each subspace of tuplespace.

Decouples storage from query. (E.g. archiver for storage, optimized for just insert, delete, dump. And in-memory data structure, such as red-black tree, optimized for sorted query.)

Each client can have its own matching agorithms and api -- matching is not part of the comm protocol, which is defined purely in terms of tuples.

Data replication is easy--hard to avoid in fact.

security -- ssh tunnels

Limitations
===========

The main limitation of tupelo is that all messages (transaction data transport) pass through a single process, the message sequencer. This process has minimal state and minimal computation: the state is just a counter and the network connections, and the computation is just counter increment and message dispatch. Nevertheless, this process is a bottleneck. All network communication passes through two hops, to and from the message sequencer. Each tupelo client must be connected to the message sequencer to operate on tuples (aside from local reads).

**Tupelo will always have this limitation.** It is essential to the design of the system. By accepting this price, you get the benefit of:

* strong consistency: all clients have the same view of the tuplespace at a given tick of the global clock

* deterministic transaction execution across processes

* high concurrency: no interprocess locking or coordination

* efficient distribution of transaction workload off of the critical path: transaction preparation (finding matching tuples) is performed by a single client

* client-side logic within transactions: any client state can be accessed while preparing a transaction

* zero-latency reads (for subscribed tuples, which depends on configuration)

* relatively easy data replication (all subscribers to a subspace replicate that subspace, possibly with different storage).

The message sequencer is also a SPoF (single point of failure), but this is not inherently necessary. Some future version of tupelo will have options for failover of the message sequencer, perhaps based on [raft](http://raftconsensus.github.io), with a cost of increased latency and complexity.

Some apparent limitations of naive use of tupelo (high client memory use, high bandwidth use, high client cpu use) can be controlled with [subspaces](doc/subspace.md) and specialized data structures and data stores.


Future
======

- More persistence options.

- Fail-over. Robustness.

- Interoperable client and server implementations in C, Python, Go, Elixir?

- UDP multicast to further reduce the bottleneck in the message sequencer. Maybe use zeromq's multicast.

- Tupelo as a service; specialized and replicated subspace managers as services.


Development
===========

Patches and bug reports are most welcome.

This project is hosted at

https://github.com/vjoel/tupelo

Dependencies
------------

Gems that were developed to support this project:

* https://github.com/vjoel/atdo

* https://github.com/vjoel/easy-serve

* https://github.com/vjoel/funl

* https://github.com/vjoel/object-stream

* https://github.com/vjoel/object-template

Other gems:

* msgpack

* yajl-ruby (only used to support --json option)

Optional gems for some of the examples:

* sinatra, http, sequel, sqlite, rbtree, leveldb-native, lmdb

Contact
=======

Joel VanderWerf, vjoel@users.sourceforge.net, @JoelVanderWerf.

License and Copyright
========

Copyright (c) 2013-2014, Joel VanderWerf

License for this project is BSD. See the COPYING file for the standard BSD license. The supporting gems developed for this project are similarly licensed.
