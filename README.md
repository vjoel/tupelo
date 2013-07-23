tupelo
==

A tuplespace that is fast, scalable, and language agnostic.

This is the reference implementation in ruby. It should be able to communicate with implementations in other languages. Planned implementation languages include C, Python, and Go.

Tupelo differs from other spaces in several ways:

* minimal central storage: the only state in the server is a counter and socket connections

* minimal central computation: just counter increment, message dispatch, and connection management

* clients do all the tuple work: registering and checking waiters, matching, searching, notifying, storing, inserting, deleting, persisting, etc. Each client is free to to decide how to do these things (application code is insulated from this, however). Special-purpose clients may use specialized algorithms and stores for the subspaces they manage.

* replication is inherent in the design (in fact it is unavoidable), for better or worse.


Getting started
==========

1. Install ruby 2 (not 1.9) from http://ruby-lang.org. Examples and tests will not work on windows (they use fork and unix sockets), though probably the underying libs will (using tcp sockets).

2. Install the gem and its dependencies:

        gem install tupelo

3. Try running tup:

        $ tup
        >> w ["hello", "world"]
        >> ra
        => [["hello", "world"]]
        >> t [nil, nil]
        => ["hello", "world"]

  If you run tup with the --info switch it will tell you the aliases to the tuple API (and also tell you much about what is happening in your transactions). Briefly:

  Write one or more tuples (and wait for the transaction to be recorded):

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

        pulse_nowait ...

  Read tuple matching a template, waiting for a match to exist:

        r <template>
        read_wait <template>

  Read tuple matching a template, without waiting for a match to exist:

        read_nowait <template>

  Read all tuples matching a template, no waiting:

        ra <template>
        read_all <template>

  If the template is omitted, reads everything (careful, you get what you ask for!). The template can be a standard template as discussed below or anything with a #=== method. Hence

        ra Hash

  reads all hash tuples (and ignore array tuples), and

        ra proc {|t| t.size==2}

  reads all 2-tuples.

  Take a tuple

        t <tuple>
        take <tuple>

  Take a tuple and optimistically use the local value before the transaction is
complete:

        x_final = take <tuple> do |x_optimistic|
          ...
        end

  It's possible that the block will be called with a value different from the eventual return value. It's also possible for the block to be called more than once.

  Perform a general transaction:

        result =
          tr do |t|           # tr is alias for transaction
            rval = t.read ... # optimistic value
            t.write ...
            t.pulse ...
            tval = t.take ... # optimistic value
            [rval, tval]      # pass out result
          end

  Note that the block may get executed more than once, if there is competition for the tuples that you are trying to #take. When the block exits, however, the transaction is final and universally accepted by all clients.

4. Run tup with a server file so that two sessions can interact. Do this in two terminals in the same dir:

        $ tup svr

  (The 'svr' argument names a file that the first instance of tup uses to store information like socket addresses and the second instance uses to connect. The first instance starts the servers as child processes. However, both instances appear in the terminal as interactive shells.)

5. Look at the examples. You may need to dig a bit to find the gem installation. For example:

        ls /usr/local/lib/ruby/gems/2.0.0/gems

  Note that all bin and example programs accept blob type (e.g., --json) on command line (it only needs to be specified for server -- the clients discover it). Also, all these programs accept log level on command line. The default is --warn. The --info level is a good way to get an idea of what is happening, without the verbosity of --debug.

6. Deugging: in addition to --info, bin/tspy is also really useful, and see the debugger client in example/lock-mgr.rb.


What is a tuplespace?
=====================

A tuplespace is a service for coordination, configuration, and control of concurrent and distributed systems. The model it provides to processes is a shared space that they can use to communicate in a deterministic and sequential manner. (Deterministic in that all clients see the same, consistent view of the data.) The space contains tuples. The operations on the space are few, but powerful. It's not a database, but it might be a front-end for one or more databases.

See https://en.wikipedia.org/wiki/Tuple_space for general information and history. This project is strongly influenced by Masatoshi Seki's Rinda implementation, part of the Ruby standard library.

What is a tuple?
----------------

A tuple is the unit of information in a tuplespace. It is immutable in the context of the tuplespace -- you can write a tuple into the space and you can read or take one from the space, but you cannot update a tuple within a space.

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

It's kind of like a "JSON object", except that in the json blob case, the hash keys can only be strings. In the case of the marshal and yaml modes, tuples can contain many other kinds of objects.

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

The nil wildcard matches anything.

Here's a template for matching some hash tuples:

    {name: String, location: "home"}

This would match all tuples whose keys are "name" and "location" and whose values for those keys are any string and the string "home", respectively.

A template doesn't have to be a pattern, though. It can be anything with a #=== method. For example:
 
    read_all proc {|t| some_predicate(t)}
    read_all Hash
    read_all Array
    read_all Object

Unlike in some tuplespace implementations, templates are a client-side concept (except for subspace-defining templates), which is a source of efficiency and scalability. Matching operations (which can be computationally heavy) are performed on the client, rather than on the server, which would bottleneck the whole system.

What are the operations on tuples?
--------------------

* read - search the space for matching tuples, waiting if none found

* write - insert the tuple into the space

* take - search the space for matching tuples, waiting if none found, removing the tuple if found

* pulse - write and take the tuple; readers see it, but it cannot be taken

These operations have a few variations (wait vs nowait) and options (timeouts).

Transactions and optimistic concurrency
--------------------

Transactions combine operations into a group that take effect at the same instant in (logical) time, isolated from other transactions. However, it may take some time (both real and logical) to prepare the transaction: to find tuples that match the criteria of the read and take operations. Finding tuples may require searching (locally) for tuples, or waiting for new tuples to be written by others. Also, the transaction may fail even after matching tuples are found (when another process takes tuples of interest). Then the transaction needs to be prepared again. Once prepared, transaction is sent to all clients, where it may either succeed (globally) or fail (for the same reason as before--someone else grabbed our tuples). If it fails, then the preparation can begin again. A transaction guarantees that, when it completes, all the operations were performed on the tuples at the same logical time. It does not guarantee that the world stands still while one process is inside the `transaction {...}` block.

Transactions are not just about batching up operations into a more efficient package (though you can do that with the #batch api). A transaction makes the combined operations execute atomically: the transaction finishes only when all of its operations can be successfully performed. Writes and pulses can always succeed, but takes and reads only succeed if the tuples exist.

Transactions give you a means of optimistic locking: the transaction proceeds in a way that depends on preconditions. See example/increment.rb for a very simple example. Not only can you make a transaction depend on the existence of a tuple, you can make the effect of the transaction a function of existing tuples (see example/transaction-logic.rb and example/broker-optimistic.rb).

If you prefer classical tuplespace locking, you can simply take / write lock tuples. See the examples. If you have a lot of contention and want to avoid the thundering herd, see example/lock-mgr-with-queue.rb.

If an optimistic transaction fails (for example, it is trying to take a tuple, but the tuple has just been taken by another transaction), then the transaction block is re-executed, possibly waiting for new matches to the templates. Application code must be aware of the possible re-execution of the block. This is better explained in the examples...

ACID -- Atomic and Isolated are enforced by the transactions; Consistency is enforced by the sequencer (each client's copy of the space is the deterministic result of the same sequence of operations); Durability is optional, but can be provided by the archiver (to be implemented) or other clients.

On the CAP spectrum, tupelo tends towards consistency.

These transactions do not require two-phase commit, because they are less powerful than general transactions. Each client has enough information to decide (in the same way as all other clients) whether the transaction succeeds or fails. This imposes a limitation on transactions over subspaces...


Advantages
==========

Tupelo can be used to impose a unified transactional structure and distributed access model on a mixture of programs and stores. ("Polyglot persistence".) Need examples....

Speed (latency, throughput):

* minimal system-wide bottlenecks

* read -- local and hence very fast

* write -- fast, pipelined (waiting for acknowledgement is optional);  

* transactions -- combine several takes and writes, reducing latency and avoiding locking

Can use optimal data structure for each subspace of tuplespace.

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

- Subspaces. Redundancy, for read-heavy systems (redundant array of in-memory sqlite, for example). Clients managing different subspaces may benefit by using different stores and algorithms.

- More persistence options.

- Fail-over. Robustness.

- Investigate nio4r for faster networking.

- Interoperable client and server implementations in C, Python, Go, ....

- UDP multicast.

- Tupelo as a service; specialized and replicated subspace managers as services.



Comparisons
===========

Redis
-----

Unlike redis, computations are not a centralized bottleneck. Set intersection, for example.

Pushing data to client eliminates need for polling, makes reads faster.

However, tupelo is not a substitute for the caching functionality of redis and memcache.


Rinda
-----

Very similar api.

No central bottleneck.

Rinda is rpc-based, which is slower and also more vulnerable due to the extra client-server state; tupelo is imlemented on a message layer, rather than rpc. This also helps with pipelined writes.

Tupelo also supports custom classes in tuples, but only with marshal / yaml; must define #==; see example/custom-class.rb

Both: tuples can be arrays or hashes.


To compare
----------

* beanstalkd

* resque

* zookeeper -- totally ordered updates

* chubby

* doozer

* hazelcast

* lmax -- minimal spof

* datomic -- similar distribution of "facts", but not tuplespace


Architecture
============

Two central processes:

* message sequencer -- assigns unique increasing IDs to each message (a message is essentially a transaction containing operations on the tuplespace). This is the key to the whole design. By sequencing all transactions in a way that all clients agree with, the transactions can be applied (or rejected) by all clients without further negotiation.

* client sequencer -- assigns unique increasing IDs to clients when they join the distributed system

Specialized clients:

* archiver -- dumps tuplespace state to clients joining the system later than t=0

* tup -- command line shell for accessing (and creating) tuplespaces

* tspy -- uses the notification API to watch all events in the space

* queue / lock / lease managers (see examples)

General application clients:

* contain a worker thread and any number of application-level client threads

* worker thread manages local tuplespace state and requests to modify or access it

* client threads construct transactions and wait for results (communicating with the worker thread over queues)

Protocol
--------

Nothing in the protocol specifies local searching or storage, or matching, or notification, or templating. That's all up to each client. The protocol only contains tuples and operations on them (take, write, pulse, read), combined into transactions.

The protocol has two layers. The outer (message) layer is 6 fields, managed by the funl gem, using msgpack for serialization.

The inner (blob) layer manages one of those 6 field using msgpack (by default), marshal, json, or yaml. This layer contains the transaction operations. The blob is not unpacked by the server, only by clients.

Each inner serialization method ("blobber") has its own advantages and drawbacks:

* marshal is ruby only, but can contain the widest variation of objects

* yaml is portable and humanly readable, and still fairly diverse, but very inefficient

* msgpack and json (yajl) are both relatively efficient (in terms of packet size, as well as parse/emit time)

* msgpack and json both support non-blocking (buffered) reads, which can avoid bottlenecks due to slow senders or bad networks.

* msgpack and json support the least diversity of objects (just "JSON objects"), but msgpack also supports hash keys that are objects rather than just strings.

For most purposes, msgpack is the right default choice.


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


Contact
=======

Joel VanderWerf, vjoel@users.sourceforge.net.

License and Copyright
========

Copyright (c) 2013, Joel VanderWerf

License for this project is BSD. See the COPYING file for the standard BSD license. The supporting gems developed for this project are similarly licensed.
