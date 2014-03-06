Tupelo
==

Tupelo is a language-agnostic tuplespace for coordination of distributed programs. It is designed for distribution of both computation and storage, on disk and in memory. Its programming model is semantically simple and transparent yet powerful: the interface is in terms of tuples, a small set of operations on tuples (read, write, take), and transactions composed of these operations. This model, unlike RPC and message channels, decouples application endpoints from each other, in both space and time.

Tupelo is inspired by Masatoshi Seki's Rinda in the Ruby standard library, which in turn is based on Gelernter's Linda. The programming models are similar, except for the lack of transactions in Rinda. However, the implementations of the two are nearly opposite in architectural approach.

This repository contains the reference implementation in Ruby, with documentation, tests, benchmarks, and examples. Implementations in other languages must communicate with this one.


Documentation
============

Introductions
-------------
* [Tutorial](doc/tutorial.md)
* [Examples](example)
* [FAQ](doc/faq.md)

In Depth
--------
* [Transactions](doc/transactions.md)
* [Replication](doc/replication.md)
* [Subspaces](doc/subspace.md)
* [Causality](doc/causality.md)
* [Concurrency](doc/concurrency.md)

The Bigger Picture
------------------
* [Comparisons](doc/compare.md)
* [Planned future work](doc/future.md)

Internals
---------
* [Architecture](doc/arch.md)
* [Protocols](doc/protocol.md)

Talk
----
* [Abstract](sfdc.md) and [slides](doc/sfdc.pdf) for San Francisco Distributed Computing meetup, November 2013.


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

4. Take a look at the [FAQ](doc/faq.md), [tutorial](doc/tutorial.md), and the many [examples](example).


Applications
=======

Tupelo is a flexible base layer for various distributed programming patterns and techniques: job queues, shared config and state, load balancing, service discovery, in-memory data grids, dataflow, map-reduce, and both optimistic and lock/lease concurrency models . The examples explore these patterns in simple forms.

Tupelo can be used to impose a unified transactional structure and distributed access model on a mixture of programs and languages (polyglot computation) and a mixture of data stores (polyglot persistence), with consistent replication.


Limitations
===========

The main limitation of tupelo is that **all network communication passes through a single process**, the message sequencer. This process has minimal state and minimal computation. The state is just a counter and the network connections (no storage of tuples or other application data). The computation is just counter increment and message dispatch (no transaction execution or searches). The message sequencer is light and fast.

Nevertheless, this process is a bottleneck. Each message traverses two hops, to and from the sequencer. Each tupelo client must be connected to the sequencer to transact on tuples (aside from local reads).

**Tupelo will always have this limitation.** It is essential to the design of the system. By accepting this cost, we get some benefits, discussed in the next section.

The message sequencer is also a SPoF (single point of failure), but this is not inherent in the design. A future version of tupelo will have options for failover or clustering of the sequencer, perhaps based on [raft](http://raftconsensus.github.io), with a cost of increased latency and complexity. (However, reduncancy and failover of *application* data and computation is supported by the current implementation.)

There are some limitations that may result from naive application of tupelo: high client memory use, high bandwidth use, high client cpu use. These resource issues can often be controlled with [subspaces](doc/subspace.md) and specialized data structures and data stores. There are several examples addressing these problems.

This implementation is also limited in efficiency because of its use of Ruby.

Finally, it must be understood that work on tupelo is still in early, experimental stages. **The tupelo software should not yet be relied on for applications where failure resistance and recovery are important.**


Advantages
==========

As noted above, Tupelo assigns an incrementing sequence number, or *tick*, to each transaction. This design choice leads to:

* strong consistency: all clients have the same view of the tuplespace at a given tick of the global clock;

* deterministic transaction execution across processes (transactions reference concrete tuples, not templates or queries that require further searching);

* high concurrency: no interprocess locking or coordination is needed to prepare or execute transactions;

* efficient distribution of transaction workload off of the critical path: transaction preparation (finding matching tuples) is performed by just the one client initiating the transaction, and transaction execution is performed only by clients that subscribe to subspaces relevant to the transaction;

* client-side logic within transactions: any client state can be accessed while preparing a transaction, and each client is free to use any template and search mechanism (deterministic or not), as suits the client's tuple storage;

* zero-latency reads: clients store subscribed tuples locally;

* relatively easy data replication: all subscribers to a subspace replicate that subspace, possibly with different storage implementations.

Additional advantages (not related to the message sequencing) include:

* a framework for starting and controlling child and remote processes connected to the tuplespace

* options to tunnel connections over ssh and through firewalls, for running in public clouds and other insecure environments

(Process control and tunneling are available independently of tupelo using the easy-serve gem.)


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

* sinatra, json, http, sequel, sqlite, rbtree, leveldb-native, lmdb

Contact
=======

Joel VanderWerf, vjoel@users.sourceforge.net, @JoelVanderWerf.

License and Copyright
========

Copyright (c) 2013-2014, Joel VanderWerf

License for this project is BSD. See the COPYING file for the standard BSD license. The supporting gems developed for this project are similarly licensed.
