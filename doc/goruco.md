
Why Rinda is useful, what's wrong with it, and how to fix it
----

Rinda, in Ruby's stdlib, promises the world: a distributed object store, threequals-based searching and notification, and coordination of concurrent processes using the simple read, write, and take operations. It's a great sandbox for learning about concurrent and distributed programming. Learn Rinda, and you'll want to use it for everything: dataflow topologies, map-reduce, work queues, pub-sub, config shares, service discovery.

In practice, though, Rinda isn't used much, for good reasons. It imposes a locking style of concurrency control. It's hard to recover from client failure. Server failure is not recoverable. The tuple store is a flat array. Query time is linear in store size. Insert time is linear in number of waiters. Every operation is a bottleneck. There is no replication or persistence. RPC is a burden. And only Ruby programs can connect to it.

Trying to fix Rinda, I patched a few bugs and slowdowns, but found that solving the problems above demands a radical change in architecture. In Tupelo, we minimize the server and maximize the clients, in terms of computation and storage. We preserve the programming model, and, as a bonus, gain transactions and zero-latency reads.


format: 30 min

level: intermediate

Bio

Joel studied math at Harvard and Berkeley, getting his PhD for work on decompositions of finite algebraic structures. He taught at U of Louisville and then helped develop a multithreaded C++ object database used in Apple and Netscape software. Back at UC Berkeley, he worked on vehicle automation, communication, control, and safety systems, and on data analysis and simulation of transportation networks. He's been puttering with Ruby since the previous millennium. Now he works on Tupelo and RedShift, a simulation framework in Ruby and C that aims to be the open-source Simulink. He can often be found playing in traffic with wheels clamped to his feet.


has this talk been given in the past?

Yes, but only 15 minutes and to a non-Ruby audience.

http://www.meetup.com/San-Francisco-Distributed-Computing/events/153886592

past talks

http://confreaks.com/videos/165-rubyconf2009-dsls-code-generation-and-new-domains-for-ruby

http://speakerrate.com/talks/1797-dsls-code-generation-and-new-domains-for-ruby

Notes
----

problems:

* lost tuples -- if a process takes a tuple and dies, how do you recover?

* no occ -- forces you to use a locking style of concurrency control

* the tuplestore is mostly a flat array, no choice of data structure

* ineff query

  * linear search -- there is no general algo for all tuples

* queries always have to go to the network -- no localstore or cache

* everything is a bottleneck: every write, template match, wait registration, wait  notification, etc.

* no concurrency -- entire system is limited by the timeline of one thread

* no replication or persistence

* RPC-based, so more latency, hard to pipeline, more vulnerable to failures

* ruby only

* marshal is slow and blocky (no buffered, non-blocking reads)

approach:

* minimize the center
  
  * just a counter and message dispatcher, no other state or computation
  
  * to remove (almost) all computational bottlenecks
  
  * to avoid centralized storage that can only use flat arrays

* preserve api, prog model, semantics

  * even add powerful transactions for OCC

  * and for efficiency and for failure resistence

  * add optional persistence

  * replication inherent in design

* open up new avenues of optimization

  * specialized data stores and search algos

  * subspaces to control resource usage

