Tupelo
==

A tuplespace that is fast, scalable, and language agnostic. It is designed for distribution of both computation and storage (disk and memory), in a unified language that has both transactional and tuple-operation (read/write/take) semantics.

This is the reference implementation in ruby. It should be able to communicate with implementations in other languages.

Documentation
============

* [Tutorial](doc/tutorial.md)
* [FAQ](doc/faq.md)
* [Comparisons](doc/compare.md)
* [Transactions](doc/transactions.md)
* [Replication](doc/replication.md)
* [Subspaces](doc/subspace.md)
* [Examples](example/)

Internals
---------
* [Architecture and protocol](doc/arch.md)

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

4. Take a look at the [FAQ](doc/faq.md), [tutorial](doc/tutorial.md), and many [examples](example/).


Applications
=======

Tupelo is a flexible base layer for various distributed programming paradigms: job queues, dataflow, map-reduce, etc.



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

Limitations
===========

Better for small messages, because they tend to propagate widely.

May stress network and local memory (but subspaces can help).

Worker thread has cpu cost (but subspaces can help).

What other potential problems and how does tupelo solve them?


Future
======

- Subspaces. Redundancy, for read-heavy data stores (redundant array of in-memory sqlite, for example). Clients managing different subspaces may benefit by using different stores and algorithms.

- More persistence options.

- Fail-over. Robustness.

- Investigate nio4r for faster networking, especially with many clients.

- Interoperable client and server implementations in C, Python, Go, Elixir?

- UDP multicast to further reduce the bottleneck in the message sequencer.

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

* sinatra, http, sequel, sqlite, rbtree, leveldb-native

Contact
=======

Joel VanderWerf, vjoel@users.sourceforge.net, @JoelVanderWerf.

License and Copyright
========

Copyright (c) 2013, Joel VanderWerf

License for this project is BSD. See the COPYING file for the standard BSD license. The supporting gems developed for this project are similarly licensed.
