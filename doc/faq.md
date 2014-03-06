FAQ about tupelo
---

Basic
=====


What is a tuplespace?
---------------------

A tuplespace is a service for coordination, configuration, and control of concurrent and distributed systems. The model it provides to processes is a shared space that they can use to communicate in a deterministic and sequential manner. (Deterministic in that all clients see the same, consistent view of the data.) The space contains tuples. The operations on the space are few, but powerful. It's not a database, but it might be a front-end for one or more databases.

See https://en.wikipedia.org/wiki/Tuple_space for general information and history. This project is strongly influenced by Masatoshi Seki's Rinda implementation, part of the Ruby standard library, though the implementation is quite different. See http://pragprog.com/book/sidruby/the-druby-book for a good introduction to rinda and druby.

A tuplespace is a kind of virtual shared memory: http://lindaspaces.com/products/vsm.html. Note particularly that VSM is different from message passing. Note that, since the sharing is virtual, there need not be any single process which stores all of the data.

See http://dbmsmusings.blogspot.com/2010/08/problems-with-acid-and-how-to-fix-them.html for an explanation of the importance of determinism in distributed transaction systems.

What is a tuple?
----------------

A tuple is the unit of information in a tuplespace. It is immutable in the context of the tuplespace -- you can write a tuple into the space and you can read or take one from the space, but you cannot update a tuple within a space. A tuple does not have an identity other than the data it contains (this is also known as associative or content-addressable storage). A tuplespace can contain multiple copies of the same tuple. (In the ruby client, two tuples are considered the same when they are #==.)

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

The empty tuples `[]` and `{}` are allowed, but bare values such as `3.14` or `false` are not tuples by themselves.

It's kind of like a "JSON object", except that, when using the json serializer, the hash keys can only be strings. In the msgpack case, keys have no special limitations. In the case of the marshal and yaml modes, tuples can contain many other kinds of objects. For example:

    $ tup --marshal
    >> w [1, 2, :three, 4..7, String, Time.now, Process.times]
    => <Tupelo::Client::Transaction done at global_tick: 3 write [1, 2, :three, 4..7, String, 2014-03-05 22:15:19 -0800, #<struct Process::Tms utime=3.17, stime=0.46, cutime=0.0, cstime=0.0>]>
    >> ra
    => [[1, 2, :three, 4..7, String, 2014-03-05 22:15:19 -0800, #<struct Process::Tms utime=3.17, stime=0.46, cutime=0.0, cstime=0.0>]]

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

For more on operations, see also [Transactions](doc/transactions.md).

Syntax: what's the diff between blocks with and without arguments?
------

You can use tupelo with a simplified syntax, like a "domain-specific language". Each construct with a block can be used in either of two forms, with an explicit block param or without. Compare [example/add-dsl.rb](example/add-dsl.rb) and [example/add.rb](example/add.rb).

What is a tupelo client?
------------------------

A client is a process (possibly with multiple threads, typically with a worker thread) that connects to the message sequencer and sends and receives transactions as messages. A client, as discussed in [protocol.md](protocol.md) must also store enough of the tuplespace state to be able to prepare and execute transactions consistently with other clients. So, it is a "client" from the point of view of the message sequencer, but a tupelo client may at the same time be serving data to other (non-tupelo) processes, such as http API clients that do not know about tupelo, as in [example/multitier](example/multitier).

Utility
=======

1. What tradeoffs does tupelo make?

  See also the limitations section [here](../README.md).

  The first question about any new distributed system should be this one. Tupelo chooses low latency over the (relative) partition tolerance of zookeeper. Tupelo chooses consistency over availability. Tupelo has a bottleneck process which all communication passes through; this does increase latency and limit throughput, but it means that all operations occur on the same timeline, and transactions execute deterministically in each replica without the need for two-phase commit. Tupelo eagerly pushes (subscribed) data to clients, rather than waiting for requests; this costs something in terms of network usage, but buys you lower latency for reads (also, it makes it possible to prepare and execute transactions on the tupelo clients without extra coordination, and to keep replicas consistent). Transactions in tupelo also make a severe tradeoff: they cannot cross subspace boundaries, but they execute deterministically without any coordination or locking.

2. How does tupelo work?

  The central concept is the global timeline of events (the 'tick' counter incremented by the message sequencer as it multicasts messages to subscribers). This guarantees the following consistency property: if a tupelo client has seen all events (i.e. transactions) up to tick n, then the local state at that cilent agrees with all other clients who have seen the same ticks. This makes local reads possible, as well as locally prepared transactions.

3. What is tupelo not good for?

  Some uses that tupelo is not good for:

  High availability, very large scale systems.
  
  Tupelo is designed for coordination, rather than large data blobs. If you need to coordinate processing of large blobs, consider definine metadata (links, ids, whatever) and using tupelo to coordinate the metadata.
  
  High volume stream data. For low volume stream data, see [chat](example/chat/chat.rb). For using tupelo to coordinate access to high volume data, see [socket-broker.rb](example/socket-broker.rb).
  
  Applications that cannot accept a SPoF (though in the future, "SPoF" may be reduced to simply a "bottleneck" by replicating the message sequencer).

4. What is tupelo good for? What are the "use cases"?

  Read scaling out (redundant array of sqlite example)
  
  Process coordination of complex background job; dataflow more complex than map-reduce
  
  Lightweight coordination: when you need task queues or other mechanisms and you don't want to run a standalone queue server.

5. Is tupelo a database?

  No. It's really more of a middleware. Tupelo doesn't have its own disk storage, indexing, queries, etc. It depends on other programs to provide these. That's actually a strength, since you can use different storage backends for different cases (subspaces, for example). Furthermore, those backends are not just storage, but unlimited processing in potentially any language that can talk the msgpack-based tupelo protocol.

6. Is tupelo a web framework or application?

  No. But see the [web examples](example/multi-tier).
  Also, tuple space has some similarities to REST: the emphasis on objects with few verbs, and constraints on the meaning of those verbs.

7. What's really new about tupelo?

  Tupelo combines these ideas:

  - Atomic broadcast/multicast, virtual synchrony

  - Tuplespace operation semantics (write, read, take)

  - Transactions

All of these are old ideas, but putting the three together is possibly new.

8. A tuplespace looks like a big global variable that is shared across processes. Isn't it a bad idea to have all that mutable global state?

  Like a database? There are reasons to prefer global state. By contrast, state that is encapsulated within program objects is closely coupled with the implementation of those objects: the language, data structures, and algorithms used, etc. As argued [here](http://scattered-thoughts.net/blog/2014/02/17/local-state-is-harmful) and [here](http://awelonblue.wordpress.com/2012/10/21/local-state-is-poison), encapsulated state makes programs harder to understand and harder to extend in certain ways. In the context of tupelo, here are some points to consider:
  
  * The history of global state is completely observable, and the history is the same for all observers. You can see this with the --trace switch to any tupelo app (or by using the tracing API).
  
  * Transitions from one state to another happen only as a result of a limited set of operations (write and take).
  
  * What this state consists of, and what changes as the state transitions to a new state, is independent of programs. It's just tuples, not data structures in some programming language.
  
  * In tupelo, transactions, in the form that they are sent between processes, don't contain templates, only tuples. The evolution of global state can be specified and understood without reference to matching. Matching is a purely client-side concept (except when used to define subspaces).

Also, it's not as bad as a truly global variable: subspaces can constrain the scope of some state to only those process that need to know about that part
.

Tuplespace Operations
=====================

1. Why no update operation?

  Tuples are immutable while in the space. However, you can update by doing #take and #write in a transaction:
    
        transaction do
          _, n = take ["my counter", Integer]
          write ["my counter", n+1]
        end

  Some storage providers may detect this take-write and perform a more efficient update instead.

2. With only three basic operations, how is it possible to perform more general database queries?

  A querying client can write a tuple that represents a query, and a responding client can take that tuple, perform the query, and write a response. See [example/subspaces/addr-book.rb](example/subspaces/addr-book.rb).

3. Do I have to worry about retrying operations? What about idempotence to ensure that retried operations have no ill effects?

  If a transaction in the block form (or a `take` or a `write_wait`) returns to the calling code, then it has (or will have) executed exactly once on all clients connected to the tupelo message sequencer. If you use `transaction` without a block, then you will need to rescue TransactionFailure and retry the transaction, which will execute at most once.

4. If reads are local, then why are reads included in the transaction as it is sent to remote processes?

  In a transaction, a read acts as an assertion that a certain tuple exists. If that tuple has disappeared after the #commit call and before the execution of the transaction, then the "assertion" fails and so does the transaction.

5. If a tranasction is all reads, does it go out to the network?

  No, it reads locally. The read results are guaranteed to be globally consistent at the tick when the read executes.

6. How do I read with a timeout?

  The easiest way is to wrap the read(s) in a transaction with a timeout:

      val =
        begin
          transaction timeout: 3.0 do
            read ["something"]
          end
        rescue TimeoutError
          nil
        end


Transactions
============

1. What kind of clocks does tupelo use?

  Tupelo does not use wall clocks for any distributed coordination: tupelo never compares timestamps generated on different systems. The only use of wall clock time is purely client-side, to manage client-requested transaction timeouts. Transactions are globally linearly ordered by a "tick" counter in the message sequencer.

2. Are transactions concurrent? What's happening in parallel?

  Let's break this into two cases: _preparing_ transactions (before attempting to commit) and _executing_ transactions (which determines whether the commit succeeds).

  During the _prepare_ phase, each transaction is a separate sequence of events (calls to #read, #write, #take et al) that executes concurrently with other transactions and *locally* in the client process. There is no synchronization between two concurrent transactions in in this stage (and this is true whether the two transactions are in two threads in the same process or in two processes in the same or different hosts). For example:

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

  Before the `t1.commit`, there is no synchronization. So both t1 axnd t2 were able to take the tuple [3], but only in the context of preparing the transactions.

  Typically, there is one transaction at a time per thread, unlike in the above example. Tupelo supports multiple client threads per process. The client threads interact with a single worker thread that manages the local subspaces and the communication with the message sequencer.

  After #commit, the transaction executes on all clients that subscribe to the affected subspaces, resulting (deterministically, the same for all clients) in either success or failure. These executions are performed by the worker thread in each client in (deterministic) linear order based on the tick. In this phase, there is no synchronization among proceses or threads, except that, within a process, a client thread that is waiting for a template match (#read or #take) will be notified by the worker thread when the match arrives (or immediately if the match already exists). For example:

      >> Thread.new { read {|x| puts "Got #{x}"} }
      => #<Thread:0x007f677b93f258 run>
      >> write ["some", "tuple"]
      Got ["some", "tuple"]

  The lack of many points of synchronization means that client threads run mostly in parallel, if the language/hardware permit, and separate client processes are completely parallel except for waiting for template matches.

3. How do transactions fail?

  Let's consider for the moment only failures due to concurrency, and exclude external causes such as host or network problems, or program-generated errors. Then transactions have two failure modes.

  During the prepare phase, transaction A can fail because some other transaction, B, successfully committed a take of a tuple that A has assumed to exist, by calling #read or #take. In this case, the transaction will roll back to its starting point and (if using the block syntax) automatically retry. You can see this in action, by running two transactions, interleaved as shown:

      $ tup
      >> w [1]
      => Tupelo::Client::Transaction done at global_tick: 1 write [1]
      >> txn = transaction
      => Tupelo::Client::Transaction open 
      >> txn.take [1]
      => [1]
      >> txn
      => Tupelo::Client::Transaction open take RubyObjectTemplate: [1]
      >> take [1] # NOTE: this is a different, concurrent transaction
      => [1]
      >> txn
      => Tupelo::Client::Transaction failed take RubyObjectTemplate: [1] missing: [[1]]

  After the transaction has been sent through the sequencer (either by calling #commit or by reaching the end of the syntactic block), it can fail for essentially the same reason: another transaction happened first, and a tuple is missing. This is harder to see using interactive tools, because the latency window between the #commit call and execution is too short. However, with higher load and contention for a small set of tuples, you can see this failure quite easily using the ``--trace`` switch. For example, [example/lock-mgr.rb](example/lock-mgr.rb) and  [example/map-reduce/prime-factor.rb](example/map-reduce/prime-factor.rb).
  
 Note that the ``--trace`` switch only indicates failures after commit. Failures can also occur during the preparation of a transaction when some other process takes a tuple; these failures are internal to a client process, and show up in the info logs. To see both kinds of failure, both pre and post commit, this is useful:

    ruby prog.rb --trace --info 2>&1 | grep -i fail


4. Do transactions nest?

  No. Not really. It's ok to syntactically enclose one transaction block in another, but they aren't truly nested in the sense that aborting the outer transaction also rolls back the inner one. The two transactions are just concurrent, independent transactions.
  Do not let a nested transaction use tuples from an enclosing transaction that has not yet executed. See [example/nest.rb](example/nest.rb).

5. If reads are handled locally, then what's difference between a read inside and outside of a transaction?

  Read outside of a transaction:

    read [1]

Read inside of a transaction:

    transaction do
      read [1]
      take [2]
    end

Differences:

* Latency. The first case will have no network latency, unless it has to wait because [1] does not exist. In, the second case, the read call returns immediately if [1] is available, but the transaction as a whole always has a latency of one round-trip, or more if there was contention for those tuples (another process takes [2] after the transaction commits but before it executes).

* Consistency. both cases have the same basic consistency guarantee: at the tick when it executes (that is, the tick observed locally--the most recent tick that the worker thread has heard), the tuple [1] exists. However, in the first case, the tick is just whatever tick it was when the tuple was found locally. In the second case, the tick is the tick at which *both* of those operations were successfully performed--so you have the additional guarantee that [1] and [2] existed **at that same time** and that [2] was removed at that time.


Distributing
============

1. How can I distribute work to multiple CPUs?

  For multiple CPUs in one host, the best way is to use unix domain sockets, which are a bit more efficient than TCP sockets (and manageable as files). This is actually the default for tup and other programs. You can use the #child method inside of an application block to start a child process connected to the tuplespace by UNIX sockets, as most of the examples do. You can also connect to an already running tuplespace from an unrelated (non-child) process; simply pass the service config to it, as in `tup sv`.
  
2. How can I distribute work to networked hosts?

  For multiple hosts, you can use the #remote method in place of #child (if you want the remote processes to be controlled by a main process, such as for batch map-reduce jobs) or you can use the service config file (which you can either copy or reference remotely using scp syntax) if you want a process with a more independent life cycle. For example:

  On my_host, start the server (let's use tup for simplicity, but it could be any app) and indicate that we are using tcp (but let tupelo choose ports):

      tup sv.yaml tcp

  and then on another host:

      scp my_host:sv.yaml .
      tup sv.yaml

  or

      tup my_host:sv.yaml

  You may want to use ssh tunneling:

      tup my_host:sv.yaml --tunnel

  See the section on security below for more details.

3. How can I distribute work to programs written in other languages?

  Help write a client!


Performance
===========

1. What factors determine the latency of a request?

  A #read is always local (no network hops). A Transaction#commit generally requires one round-trip to the message sequencer (two network hops).

2. How can I reduce latency?

  Use #write (same as #write_nowait) instead of #write_wait. The usual warnings for un-acked writes apply, but if some later write or other transaction succeeds, then all previous ones did.

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
  (For another example of optimistically taking tuples, see the next section.)
  Another advantage of the transaction is that it is atomic, so a network failure or hardware failure in the client between the #take and the #write will not cause the tuple to be lost, as it would in the first case.

3. What's the load-balancing story? How do I do that in tupelo?

  Tupelo processes have the advantage that new tuples get pushed to the local replica of the tuplespace, where they can be read with no network latency. This means that each process has nearly complete information about all the work items that are available. Of course, coordination between these processes still takes time (using write and take). If you take advantage of this, you can sometimes reduce contention and increase throughput. For example, see [naive](example/map-reduce/prime-factor.rb) and [optimized](example/map-reduce/prime-factor-balanced.rb) implementations of load-balanced distributed prime factoring. In that case, there is about a 50% improvement in throughput.

Apps, Tools, Command-line Interface
===================================

1. Why is there no CLI for a single transaction or operation, like maybe `tup ... "read [...]"`?

  This would only make sense for write and pulse ops, not read or take. The
reason is that #read and #take depend on the client being subscribed to the subspace to which the ops apply. Subscribing may involve significant data transfer, depending on the size of the subspace. It is not generally efficient to do this for a single operation. Use bin/tup instead.

2. Can I use tupelo without the Application framework?

  Yes. The Application class is useful for examples and tests. It is suitable for more complex applications if their source code fits the framework. But it may force you into certain decisions that make it difficult to integrate into other code. One example is [example/small.rb](example/small.rb). (It would be good to have an example that doesn't even use easy-serve...)

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

  Here, myhost is whatever you need to ssh into the first host (it might be username@example.com). The services file at path/to/srv is read using ssh (it doesn't have to be on the same host as the services themselves, but usually is). Then tunnels to those services are set up over the ssh connection. This is client-managed tunneling (corresponding to the -L switch for ssh).
  All the command line programs (and any program using Tupelo::Application) can make use of tunneling. For example, the [chat app](example/chat):
  
      host1$ ruby chat.rb chat.yaml Fred

      host2$ ruby chat.rb host1:path/to/chat.yaml Wilma --tunnel

  The procedure for server-managed tunneling (corresponding to the -R switch for ssh) is different. When a main Tupelo.application process needs to start a remote client that tunnels back to the server, simply pass `tunnel: true` to the #remote call. (In fact, if you pass --tunnel on the command line, the `true` value becomes the default for all #remote clients.) For [example](example/map-reduce/remote-map-reduce.rb).

2. How can I connect clients across private subnets and behind firewalls?

  The built-in solution in tupelo is to use ssh tunnels. If the services in the services file are accessible from a host (via tunnels, if necessary), then a tupelo client on that host can share data with other clients (it's a star topology).

3. How should I configure ssh?

  Using remotes and tunnels is much easier if you configure ssh to use control sockets to multiplex ssh sessions over a single connection per host pair. The following works well in .ssh/config:

      Host *
        ControlMaster auto
        ControlPath ~/tmp/.ssh/%r@%h:%p
        ControlPersist yes

  Note that the dir `~/tmp/.ssh` must exist, so if ~/tmp is periodically cleaned, you might want to create it in your .profile / .bashrc / .zshrc file. You can also install public ssh keys to avoid typing your password on first connection.


Debugging
=========

1. How can I see what tuples a client is getting?

  Use --trace or #notify or just add this thread:

      Thread.new do
        read {|tt| log tt}
      end

  Optionally, pass a template to #read.

2. Related to the last question, why doesn't the following loop see all tuples as they arrive in the space?

      loop do
        tuple = read some_template
        do_something_with tuple
      end

  This is wrong in two ways. First, there is a race condition. If another client thread or process does a write and a take between the iterations of the loop, then that tuple will not be seen by the read loop. Similarly, a pulse occuring at the wrong point in the loop will not be seen. Second, read is not guaranteed to read in any particular order (unless you are using a custom datastructure for your subspace and expose that ordering to the #read method). So read may simply return the same tuple over and over.

  For this use case, it is better to use read with a block:
  
      read some_template do |tuple|
        do_something_with tuple
      end

  The semantics of this construct is to iterate over each matching tuple in the space exactly once, including tuples that already existed before the read call and including tuples as they arrive. Of course, if the #do_something_with is too slow, then arriving tuples will simply queue up and not get processed in a timely manner.


Tuplets
=======


General
=======

1. Why "tupelo"?

  Resonance with "tuple", I guess... Also, I'm a fan of Uncle Tupelo. And Elvis was born in Tupelo, Miss.
