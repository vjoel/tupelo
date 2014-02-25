Transactions and optimistic concurrency
===================

Transactions combine operations into a group that take effect at the same instant in (logical) time, isolated from other transactions.

However, it may take some time to prepare the transaction. This is true in terms of both real time (clock and process) and logical time (global sequence of operations). Preparing a transaction means finding tuples that match the criteria of the read and take operations. Finding tuples may require searching (locally) for tuples, or waiting for new tuples to be written by others. Also, the transaction may fail even after matching tuples are found (when another process takes tuples of interest). Then the transaction needs to be prepared again. Once prepared, transaction is sent to all clients, where it may either succeed (in all clients) or fail (for the same reason as before--someone else grabbed one of our tuples). If it fails, then the preparation begins again. A transaction guarantees that, when it completes, all the operations were performed on the tuples at the same logical time in *all* clients. It does not guarantee that the world stands still while one process is inside the `transaction {...}` block.

Transactions are not just about batching up operations into a more efficient package. A transaction makes the combined operations execute atomically: the transaction finishes only when all of its operations can be successfully performed. Writes and pulses can always succeed, but takes and reads only succeed if the tuples exist.

Transactions give you a means of optimistic locking: the transaction proceeds in a way that depends on preconditions. See [example/increment.rb](example/increment.rb) for a very simple example. Not only can you make a transaction depend on the existence of a tuple, you can make the effect of the transaction a function of existing tuples (see [example/transaction-logic.rb](example/transaction-logic.rb) and [example/broker-optimistic.rb](example/broker-optimistic.rb)).

If you prefer classical tuplespace locking, you can simply use certain tuples as locks, using take/write to lock/unlock them. See the examples, such as [example/broker-locking.rb](example/broker-locking.rb). If you have a lot of contention and want to avoid the thundering herd, see [example/lock-mgr-with-queue.rb](example/lock-mgr-with-queue.rb).

If an optimistic transaction fails (for example, it is trying to take a tuple, but the tuple has just been taken by another transaction), then the transaction block is re-executed, possibly waiting for new matches to the templates. Application code must be aware of the possible re-execution of the block. This is better explained in the examples...

Optimistic concurrency has a significant disadvantage, however, when *contention* is high: that is, many processes are trying to use the same tuples. (See also the FAQ section on how transactions fail.) For example, 

    require 'tupelo/app'

    N = 5

    Tupelo.application do
      N.times do |i|
        child do
          transaction do
            n, _ = take [Integer]
            write [n + 1]
          end
        end
      end

      child do
        write [0]
        n, _ = take [N]
        puts "result is #{n}"
      end
    end

If you run this with the `--trace` switch, you'll see many failed transactions. This is because several processes are trying to take the same tuple, and only the first of these (the first to pass through the message sequencer) will succeed; the others will repeat the transaction preparation (running the code block again). These failures do not make the program run incorrectly, just inefficiently. The cost of a failed transaction has two parts: the computational cost of having to repeat the transaction block (including datastructure lookups) and the latency cost of the round trip to and from the sequencer.

Transactions used for optimistic concurrency have another significant disadvantage compared to using take/write to lock/unlock tuples: a transaction can protect only resources that are represented in the tuplespace, whereas a lock can protect anything: a file, a device, a service, etc. This is because a transaction begins and ends within a single instant of logical (tuplespace) time, whereas a lock tuple can be taken out for an arbitrary duration of real (and logical) time. Furthermore, the instant of logical time in which a transaction takes effect may occur at different wall-clock times on different processes, even on the same host.

Transactions do have an advantage over using take/write to lock/unlock tuples: there is no possibility of deadlock. See [example/deadlock.rb](example/deadlock.rb) and [example/parallel.rb](example/parallel.rb).

Another advantage of tranactions is that it is possible to guarantee continuous existence of a time-series of tuples. For example, suppose that tuples matching `{step: Numeric}` indicate the progress of some activity. With transactions, you can guarantee that there is exactly one matching tuple at any time, and that no client ever sees an intermediate or inconsistent state of the counter or has to wait for the counter to be incremented:

    transaction do
      step = take(step: nil)["step"]
      write step: step + 1
    end

Any client which reads the `{step: Numeric}` template will find a (unique) match without blocking. Since reads are always local, this means that every client has fast local access to the current state of the activity (the "step" in this case).

Another use of transactions: forcing a retry when something changes:

    transaction do
      step = read(step: nil)["step"]
      take value: nil, step: step
    end

This code waits on the existence of a value, but retries if the step changes while waiting. See [example/pregel/distributed.rb](example/pregel/distributed.rb) for a use of this technique in an applied setting. See [example/observer.rb](example/observer.rb) for a couple of alternative ways to implement the observer pattern: using transactions failure (as above) and using stream reads.

Tupelo transactions are ACID in the following sense. They are Atomic and Isolated -- this is enforced by the transaction processing in each client. Consistency is enforced by the underlying message sequencer: each client's copy of the space is the deterministic result of the same sequence of operations. This is also known as [sequential consistency] (https://en.wikipedia.org/wiki/Sequential_consistency). Also see the Calvin database described in http://dbmsmusings.blogspot.com/2012/05/if-all-these-new-dbms-technologies-are.html, which uses this same technique. Like tupelo, Calvin avoids 2PC, and "is not a database system itself, but rather a transaction scheduling and replication coordination service", which can "integrate with any data storage layer, relational or otherwise", and in which "replicas perform the actual processing of transactions completely independently of one another, maintaining strong consistency without having to constantly synchronize transaction results between replicas".

Durability is optional, but can be provided by the persistent archiver or other clients.

On the CAP spectrum, tupelo tends towards consistency: for all clients, write and take operations are applied in the same order, so the state of the entire system up through a given tick of discrete time is universally agreed upon. This is known as [state machine replication] (http://en.wikipedia.org/wiki/State%20machine%20replication). Of course, because of the difficulties of distributed systems, one client may not yet have seen the same range of ticks as another. Tupelo's replication model (especially in the use of subspaces) can also be described as [virtual synchrony](https://en.wikipedia.org/wiki/Virtual_synchrony). See also http://afeinberg.github.io/2011/06/17/replication-atomicity-and-order-in-distributed-systems.html.

Tupelo transactions do not require two-phase commit, because they are less powerful than general transactions. Each client has enough information to decide (in the same way as all other clients) whether the transaction succeeds or fails. This has performance advantages, but imposes some limitations on transactions over subspaces that are known to one client but not another. [Subspaces](doc/subspace.md). This tradeoff is discussed in http://dbmsmusings.blogspot.com/2012/05/if-all-these-new-dbms-technologies-are.html -- see "(2) Reduce transaction flexibility for scalability".

Note that tupelo's replication strategy does not have the same goal as, for example, raft or paxos. Tupelo's message sequencer is a single point of failure (in addition to being a bottleneck). Tupelo replicates application data, but not the state of the message sequencer itself. So as long as the mseq is running and accessible, the system can survive the loss of almost all replicas of a given subspace. Loss of the mseq is bad news. The tradeoff is this: tupelo has low latency, light resource requirements, and quick startup (compared to Zookeeper, for example), but it should only be used for applications that can accept the risk of mseq failing (for example, on-line analytics, distributed batch jobs, other disposable computation, and first-tier services, replacing redis, as in https://www.cs.cornell.edu/Projects/mrc/IEEE-CAP.16.pdf).

Transactions in tupelo are different from transactions in JavaSpaces and similar Linda-like systems: tupelo transactions are optimistic and use no locks.
