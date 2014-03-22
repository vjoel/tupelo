Comparisons
===========

Rinda
-----

Tupelo differs from Rinda in several ways:

* minimal central storage: the only state in the server is a counter and socket connections

* minimal central computation: just counter increment, message dispatch, and connection management (and it never unpacks serialized tuples)

* clients do all the tuple work: registering and checking waiters, matching, searching, notifying, storing, inserting, deleting, persisting, etc. Each client is free to to decide how to do these things (application code is insulated from this, however). Special-purpose clients (known as *tuplets*) may use specialized algorithms and stores for the subspaces they manage.

* transactions, in addition to the classic operators (and transactions execute client-side, reducing bottleneck and increasing expressiveness).

* replication is inherent in the design (in fact it is unavoidable), for better or worse.

Very similar api.

Rinda has a severe bottleneck, though: all matching, waiting, etc. are performed in one process.

Rinda is rpc-based, which is slower and also more vulnerable due to the extra client-server state; tupelo is imlemented on a message layer, rather than rpc. This also helps with pipelined writes.

Tupelo also supports custom classes in tuples, but only with marshal / yaml; must define #==; see [example/custom-class.rb](example/custom-class.rb)

Both: tuples can be arrays or hashes.

Spaces have an advantage over distributed hash tables: different clients may acccess tuples in terms of different dimensions. For example, a producer generates [producer_id, value]; a consumer looks for [nil, SomeParticularValues]. Separation of concerns, decoupling in the data space.

(One of the inspirations for Tupelo was fixing some problems with Rinda, and attempting to add some transaction-like features: https://github.com/vjoel/my-rinda.)


Redis
-----

Unlike redis, computations are not a centralized bottleneck. Set intersection, for example.

Pushing data to client eliminates need for polling, makes reads faster.

Tupelo's pulse/read ops are like pubsub in redis.

However, tupelo is not a substitute for the caching functionality of redis and memcache.


Zookeeper
---------

Both Tupelo and Zookeeper are consistent systems, and both are based on an atomic broadcast of totally ordered updates. But Tupelo has no resiliance to network partitions. If you can't see the sequencer, you can't do anything but local reads (which may go stale). With Zookeeper, if you can connect to one of a quorum of mutually connected nodes, you have full interaction with the authoritative system. Zookeeper has a cost, though: latency, multiple hosts, complexity. An advantage of Tupelo is that a complete tupelo system, including remote clients, can be started in less than a second (for example, [prime-factor.rb](example/prime-factor.rb). This is useful for quick batch dataflow jobs.

Similar comparisons probably apply for chubby and doozer, and for etcd and other raft-based CP systems.




To compare
----------

* ETS in Erlang/OTP

* calvin, h-store, voltdb

* MPI collective ops: http://www.osl.iu.edu/research/mpi.net/documentation/tutorial/collectives.php

* beanstalkd

* celery for python

* resque

* serf -- tupelo has lower latency and is transactional, but at a cost compared to serf; tupelo semantics is closer to databases

* arakoon

* hazelcast

* lmax -- minimal spof

* datomic -- similar distribution of "facts", but not tuplespace; similar use of pluggable storage managers

* job queues: sidekiq, resque, delayedjob, http://queues.io, https://github.com/factual/skuld

* message queues
  http://www.rabbitmq.com/blog/2014/02/19/distributed-semaphores-with-rabbitmq

* pubsubs: kafka

* spark, storm

* tibco and gigaspace

* gridgain

* ActorDB

