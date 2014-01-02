tupelo
==

A tuplespace that is fast, scalable, and language agnostic. It is designed for distribution of both computation and storage, in a unified language that has both transactional and tuple-operation (read/write/take) semantics.


This is the reference implementation in ruby. It should be able to communicate with implementations in other languages. Planned implementation languages include C, Python, and Go.

Tupelo differs from other spaces in several ways:

* minimal central storage: the only state in the server is a counter and socket connections

* minimal central computation: just counter increment, message dispatch, and connection management (and it never unpacks serialized tuples)

* clients do all the tuple work: registering and checking waiters, matching, searching, notifying, storing, inserting, deleting, persisting, etc. Each client is free to to decide how to do these things (application code is insulated from this, however). Special-purpose clients (known as *tuplets*) may use specialized algorithms and stores for the subspaces they manage.

* transactions, in addition to the classic operators (and transactions execute client-side, reducing bottleneck and increasing expressiveness).

* replication is inherent in the design (in fact it is unavoidable), for better or worse.

Documentation
============

* [Tutorial](doc/tutorial.md)
* [FAQ](doc/faq.md)
* [Subspaces](doc/subspace.md)
* (Examples)(example/)

* [Abstract](sfdc.md) and [slides](doc/sfdc.pdf) for San Francisco Distributed Systems meetup

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

4. Take a look at the [Tutorial](doc/tutorial.md) and many (Examples)(example/).


What is a tuplespace?
=====================

A tuplespace is a service for coordination, configuration, and control of concurrent and distributed systems. The model it provides to processes is a shared space that they can use to communicate in a deterministic and sequential manner. (Deterministic in that all clients see the same, consistent view of the data.) The space contains tuples. The operations on the space are few, but powerful. It's not a database, but it might be a front-end for one or more databases.

See https://en.wikipedia.org/wiki/Tuple_space for general information and history. This project is strongly influenced by Masatoshi Seki's Rinda implementation, part of the Ruby standard library. See http://pragprog.com/book/sidruby/the-druby-book for a good introduction to rinda and druby.

See http://dbmsmusings.blogspot.com/2010/08/problems-with-acid-and-how-to-fix-them.html for an explanation of the importance of determinism in distributed transaction systems.

What is a tuple?
----------------

A tuple is the unit of information in a tuplespace. It is immutable in the context of the tuplespace -- you can write a tuple into the space and you can read or take one from the space, but you cannot update a tuple within a space. A tuple does not have an identity other than the data it contains. A tuplespace can contain multiple copies of the same tuple. (In the ruby client, two tuples are considered the same when they are #==.)

A tuple is either an array:

    ["hello", 7]
    [nil, true, false]
    ["foo", 3.2, [6,5,4], {"bar" => 3}]

... or a hash:
 
    {name: "Myrtle", location: [100,200]}
    { [1,2] => 3, [5,7] => 12 }

In other words, a tuple is a fairly general object, though this depends on the serializer--see below. More or less, a tuple is anything that can be built out of:

* strings

* numbers

* nil, true, false

* arrays

* hashes

It's kind of like a "JSON object", except that, when using the json serializer, the hash keys can only be strings. In the msgpack case, keys have no special limitations. In the case of the marshal and yaml modes, tuples can contain many other kinds of objects.

The empty tuples `[]` and `{}` are allowed, but bare values such as `3.14` or `false` are not tuples by themselves.

One other thing to keep in mind: in the array case, the order of the elements is significant. In the hash case, the order is not significant. So these are both true:

    [1,2] != [2,1]
    {a:1, b:2} == {b:2, a:1}


What is a template?
-------------------

A template an object that matches (or does not match) tuples. It's used for querying a tuplespace. Typically, a template looks just like a tuple, but possibly with wildcards of some sort. The template:

    [3..5, Integer, /foo/, nil]

would match the tuple:

    [4, 7, "foobar", "xyz"]

but not these tuples:

    [6, 7, "foobar", "xyz"]
    [3, 7.2, "foobar", "xyz"]
    [3, 7, "fobar", "xyz"]

The nil wildcard matches anything. The Range, Regexp, and Class entries function as wildcards because of the way they define the #=== (match) method. See ruby docs for general information on "threequals" matching.

Every tuple can also be used as a template. The template:

    [4, 7, "foobar", "xyz"]

matches itself.

Here's a template for matching some hash tuples:

    {name: String, location: "home"}

This would match all tuples whose keys are "name" and "location" and whose values for those keys are any string and the string "home", respectively.

A template doesn't have to be a tuple pattern with wildcards, though. It can be anything with a #=== method. For example:
 
    read_all proc {|t| some_predicate(t)}
    read_all Hash
    read_all Array
    read_all Object

An optional library, `tupelo/util/boolean`, provides a #match_any method to construct the boolean `or` of other templates:

    read_all match_any( [1,2,3], {foo: "bar"} )

Unlike in some tuplespace implementations, templates are a client-side concept (except for subspace-defining templates), which is a source of efficiency and scalability. Matching operations (which can be computationally heavy) are performed on the client, rather than on the server, which would bottleneck the whole system.

What are the operations on tuples?
--------------------

* read - search the space for matching tuples, waiting if none found

* write - insert the tuple into the space

* take - search the space for matching tuples, waiting if none found, removing the tuple if found

* pulse - write and take the tuple; readers see it, but it cannot be taken by other client, and it cannot be read later (this is not a classical tuplespace operation, but is useful for publish-subscribe communication patterns)

These operations have a few variations (wait vs nowait) and options (timeouts).

Transactions and optimistic concurrency
--------------------

Transactions combine operations into a group that take effect at the same instant in (logical) time, isolated from other transactions.

However, it may take some time to prepare the transaction. This is true in terms of both real time (clock and process) and logical time (global sequence of operations). Preparing a transaction means finding tuples that match the criteria of the read and take operations. Finding tuples may require searching (locally) for tuples, or waiting for new tuples to be written by others. Also, the transaction may fail even after matching tuples are found (when another process takes tuples of interest). Then the transaction needs to be prepared again. Once prepared, transaction is sent to all clients, where it may either succeed (in all clients) or fail (for the same reason as before--someone else grabbed one of our tuples). If it fails, then the preparation begins again. A transaction guarantees that, when it completes, all the operations were performed on the tuples at the same logical time. It does not guarantee that the world stands still while one process is inside the `transaction {...}` block.

Transactions are not just about batching up operations into a more efficient package. A transaction makes the combined operations execute atomically: the transaction finishes only when all of its operations can be successfully performed. Writes and pulses can always succeed, but takes and reads only succeed if the tuples exist.

Transactions give you a means of optimistic locking: the transaction proceeds in a way that depends on preconditions. See [example/increment.rb](example/increment.rb) for a very simple example. Not only can you make a transaction depend on the existence of a tuple, you can make the effect of the transaction a function of existing tuples (see [example/transaction-logic.rb](example/transaction-logic.rb) and [example/broker-optimistic.rb](example/broker-optimistic.rb)).

If you prefer classical tuplespace locking, you can simply use certain tuples as locks, using take/write to lock/unlock them. See the examples, such as [example/broker-locking.rb](example/broker-locking.rb). If you have a lot of contention and want to avoid the thundering herd, see [example/lock-mgr-with-queue.rb](example/lock-mgr-with-queue.rb).

If an optimistic transaction fails (for example, it is trying to take a tuple, but the tuple has just been taken by another transaction), then the transaction block is re-executed, possibly waiting for new matches to the templates. Application code must be aware of the possible re-execution of the block. This is better explained in the examples...

Transactions have a significant disadvantage compared to using take/write to lock/unlock tuples: a transaction can protect only resources that are represented in the tuplespace, whereas a lock can protect anything: a file, a device, a service, etc. This is because a transaction begins and ends within a single instant of logical (tuplespace) time, whereas a lock tuple can be taken out for an arbitrary duration of real (and logical) time. Furthermore, the instant of logical time in which a transaction takes effect may occur at different wall-clock times on different processes, even on the same host.

Transactions do have an advantage over using take/write to lock/unlock tuples: there is no possibility of deadlock. See [example/deadlock.rb](example/deadlock.rb) and [example/parallel.rb](example/parallel.rb).

Another advantage of tranactions is that it is possible to guarantee continuous existence of a time-series of tuples. For example, suppose that tuples matching `{step: Numeric}` indicate the progress of some activity. With transactions, you can guarantee that there is exactly one matching tuple at any time, and that no client ever sees in intermediate or inconsistent state of the counter:

    transaction do
      step = take(step: nil)["step"]
      write step: step + 1
    end

Any client which reads this template will find a (unique) match without blocking.

Another use of transactions: forcing a retry when something changes:

    transaction do
      step = read(step: nil)["step"]
      take value: nil, step: step
    end

This code waits on the existence of a value, but retries if the step changes while waiting. See example/pregel/distributed.rb for a use of this techinique.

Tupelo transactions are ACID in the following sense. They are Atomic and Isolated -- this is enforced by the transaction processing in each client. Consistency is enforced by the underlying message sequencer: each client's copy of the space is the deterministic result of the same sequence of operations. This is also known as [sequential consistency] (https://en.wikipedia.org/wiki/Sequential_consistency). Also see the Calvin database described in http://dbmsmusings.blogspot.com/2012/05/if-all-these-new-dbms-technologies-are.html, which uses this same technique. Like tupelo, Calvin avoids 2PC, and "is not a database system itself, but rather a transaction scheduling and replication coordination service", which can "integrate with any data storage layer, relational or otherwise", and in which "replicas perform the actual processing of transactions completely independently of one another, maintaining strong consistency without having to constantly synchronize transaction results between replicas".

Durability is optional, but can be provided by the persistent archiver or other clients.

On the CAP spectrum, tupelo tends towards consistency: for all clients, write and take operations are applied in the same order, so the state of the entire system up through a given tick of discrete time is universally agreed upon. This is known as [state machine replication] (http://en.wikipedia.org/wiki/State%20machine%20replication). Of course, because of the difficulties of distributed systems, one client may not yet have seen the same range of ticks as another. Tupelo's replication model (especially in the use of subspaces) can also be described as [virtual synchrony](https://en.wikipedia.org/wiki/Virtual_synchrony). See also http://afeinberg.github.io/2011/06/17/replication-atomicity-and-order-in-distributed-systems.html.

Tupelo transactions do not require two-phase commit, because they are less powerful than general transactions. Each client has enough information to decide (in the same way as all other clients) whether the transaction succeeds or fails. This has performance advantages, but imposes some limitations on transactions over subspaces that are known to one client but not another. [Subspaces](doc/subspace.md). This tradeoff is discussed in http://dbmsmusings.blogspot.com/2012/05/if-all-these-new-dbms-technologies-are.html -- see "(2) Reduce transaction flexibility for scalability".


Syntax
======

You can use tupelo with a simplified syntax, like a "domain-specific language". Each construct with a block can be used in either of two forms, with an explicit block param or without. Compare [example/add-dsl.rb](example/add-dsl.rb) and [example/add.rb](example/add.rb).


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

- Interoperable client and server implementations in C, Python, Go, .... Elixir?

- UDP multicast to further reduce the bottleneck in the message sequencer.

- Tupelo as a service; specialized and replicated subspace managers as services.


Comparisons
===========

Redis
-----

Unlike redis, computations are not a centralized bottleneck. Set intersection, for example.

Pushing data to client eliminates need for polling, makes reads faster.

Tupelo's pulse/read ops are like pubsub in redis.

However, tupelo is not a substitute for the caching functionality of redis and memcache.


Rinda
-----

Very similar api.

Rinda has a severe bottleneck, though: all matching, waiting, etc. are performed in one process.

Rinda is rpc-based, which is slower and also more vulnerable due to the extra client-server state; tupelo is imlemented on a message layer, rather than rpc. This also helps with pipelined writes.

Tupelo also supports custom classes in tuples, but only with marshal / yaml; must define #==; see [example/custom-class.rb](example/custom-class.rb)

Both: tuples can be arrays or hashes.

Spaces have an advantage over distributed hash tables: different clients may acccess tuples in terms of different dimensions. For example, a producer generates [producer_id, value]; a consumer looks for [nil, SomeParticularValues]. Separation of concerns, decoupling in the data space.


To compare
----------

* beanstalkd

* resque

* zookeeper -- totally ordered updates; tupelo trades availability for lower latency (?)

* chubby

* doozer, etcd

* serf -- tupelo has lower latency and is transactional, but at a cost compared to serf; tupelo semantics is closer to databases

* arakoon

* hazelcast

* lmax -- minimal spof

* datomic -- similar distribution of "facts", but not tuplespace; similar use of pluggable storage managers

* job queues: sidekiq, resque, delayedjob, http://queues.io, https://github.com/factual/skuld

* pubsubs: kafka

* spark, storm

* tibco and gigaspace

* gridgain


Architecture
============

Two central processes:

* message sequencer -- assigns unique increasing IDs to each message (a message is essentially a transaction containing operations on the tuplespace). This is the key to the whole design. By sequencing all transactions in a way that all clients agree with, the transactions can be applied (or rejected) by all clients without further negotiation.

* client sequencer -- assigns unique increasing IDs to clients when they join the distributed system

Specialized clients:

* archiver -- dumps tuplespace state to clients joining the system later than t=0; at least one archiver is required, unless all clients start at t=0.

* tup -- command line shell for accessing (and creating) tuplespaces

* tspy -- uses the notification API to watch all events in the space

* queue / lock / lease managers (see examples)

General application clients:

* contain a worker thread and any number of application-level client threads

* worker thread manages local tuplespace state and requests to modify or access it

* client threads construct transactions and wait for results (communicating with the worker thread over queues); they may also use asynchronous transactions

Some design principles:

* Once a transaction has been sent from a client to the message sequencer, it references only tuples, not templates. This makes it faster and simpler for each receiving client to apply or reject the transaction. Also, clients that do not support local template searching (such as archivers) can store tuples using especially efficient data structures that only support tuple-insert, tuple-delete, and iterate/export operations.

* Use non-blocking protocols. For example, transactions can be evaluated in one client without waiting for information from other clients. Even at the level of reading messages over sockets, tupelo uses (via funl and object-stream) non-blocking constructs. At the application level, you can use transactions to optimistically modify shared state (but applications are free to use locking if high contention demands it).

* Do the hard work on the client side. For example, all pattern matching happens in the client that requested an operation that has a template argument, not on the server or other clients.

Protocol
--------

Nothing in the protocol specifies local searching or storage, or matching, or notification, or templating. That's all up to each client. The protocol only contains tuples and operations on them (take, write, pulse, read), combined into transactions.

The protocol has two layers. The outer (message) layer is 6 fields, managed by the funl gem, using msgpack for serialization. All socket reads are non-blocking (using msgpack's stream mode), so a slow sender will not block other activity in the system.

One of those 6 fields is a data blob, containing the actual transaction and tuple information. The inner (blob) layer manages that field using msgpack (by default), marshal, json, or yaml. This layer contains the transaction operations. The blob is not unpacked by the server, only by clients.

Each inner serialization method ("blobber") has its own advantages and drawbacks:

* marshal is ruby only, but can contain the widest variation of objects

* yaml is portable and humanly readable, and still fairly diverse, but very inefficient

* msgpack and json (yajl) are both relatively efficient (in terms of packet size, as well as parse/emit time)

* msgpack and json support the least diversity of objects (just "JSON objects"), but msgpack also supports hash keys that are objects rather than just strings.

For most purposes, msgpack is a good choice, so it is the default.

The sending client's tupelo library must make sure that there is no aliasing within the list of tuples (this is only an issue for Marshal and YAML, since msgpack and json do not support references).


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
