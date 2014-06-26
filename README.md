Tupelo
==

Tupelo is a language-agnostic tuplespace for coordination of distributed programs. It is designed for distribution of both computation and storage, on disk and in memory, with pluggable storage adapters. Its programming model is small and semantically transparent: there are tuples (built from arrays, hashes, and scalars), a few operations on tuples (read, write, take), and transactions composed of these operations. This data-centric model, unlike RPC and most forms of messaging, decouples application endpoints from each other, not only in space and time, but also in referential structure: processes refer to data rather than to other processes or to channels.

Tupelo is inspired by Masatoshi Seki's Rinda in the Ruby standard library, which in turn is based on David Gelernter's Linda. The programming models of Tupelo and Rinda are similar, except for the lack of transactions in Rinda. However, the implementations of the two are nearly opposite in architectural approach.

This repository contains the reference implementation in Ruby, with documentation, tests, benchmarks, and examples. Implementations in other languages must communicate with this one.

News
====

* 2014-June-26: Slides and videos from my talk on Calvin, which has some ideas in common with tupelo (plus a lot more):
  * http://www.meetup.com/papers-we-love-too/events/171291972
  * https://speakerdeck.com/paperswelove/pwlsf-number-4-equals-joel-vanderwerf-on-calvin
  * https://plus.google.com/events/cprsf9edesa0ghm3b8c416ppa7o

* 2014-April-7: Want to use these fancy stores inside a client that you run from the command line? See [here](example/sqlite/README.md) and [here](example/riemann/README.md).

* 2014-April-1: [Riemann example](example/riemann) uses more stores in various roles:

  * sqlite store for the consumer replicas, with indexes for
    * service/host/time
    * tags
    * custom data
  * rbtree store for the expirer
  * hash store for the alerter

* 2014-March-19: release 0.21
    
    * correct use of `store` and `space` terms everywhere
    * sqlite example improvements
    * API additions
      * tuplestores can define #find_all_matches_for
        * for efficient search in #read_all
      * msgpack and json options to deserialize keys as symbols
        * invoke via Client option and tup switch

See also https://github.com/vjoel/tupelo/releases.

Documentation
============

Introductory
------------
* [Tutorial](doc/tutorial.md)
* [Examples](example)
* [FAQ](doc/faq.md)

In Depth
--------
* [Transactions](doc/transactions.md)
* [Replication](doc/replication.md)
* [Subspaces](doc/subspace.md)
* [Tuple stores](doc/tuplestores.md)
* [Causality](doc/causality.md)
* [Concurrency](doc/concurrency.md)

Big Picture
-----------
* [Comparisons](doc/compare.md)
* [Planned future work](doc/future.md)

Internals
---------
* [Architecture](doc/arch.md)
* [Protocols](doc/protocol.md)

Talk
----
* [Abstract](sfdc.md) and [slides](doc/sfdc.pdf) for San Francisco Distributed Computing meetup, December 2013.


Getting started
==========

1. Install ruby 2.0 or 2.1 (not 1.9) from http://ruby-lang.org. Examples and tests will not work on Windows (they use fork and unix sockets) or JRuby, though probably the underying libs will (using tcp sockets on Windows).

2. Install the gem and its dependencies (you may need to `sudo` this):

        gem install tupelo

3. Try running tup:

        $ tup
        >> w ["hello", "world"]
        >> ra
        => [["hello", "world"]]
        >> t [nil, nil]
        => ["hello", "world"]

4. Take a look at the [FAQ](doc/faq.md), the [tutorial](doc/tutorial.md), and the many [examples](example).


Applications
=======

Tupelo is a flexible base layer for various distributed programming patterns and techniques, which are explored in the examples: job queues, shared configuration and state, load balancing, service discovery, in-memory data grids, message queues, publish/subscribe, dataflow, map-reduce, and both optimistic and pessimistic (lock/lease) concurrency control.

Tupelo can be used to impose a unified transactional structure and distributed access model on a mixture of programs and languages (polyglot computation) and a mixture of data stores (polyglot persistence), with consistent replication.

See the [example section](#examples) below and the [examples](example) directory.


Limitations
===========

Bottleneck
----------

The main limitation of tupelo is that, except for read-only operations, **all tuple operations pass through a single process**, the message sequencer.

The sequencer has minimal state and minimal computation. The state is just a counter and the network connections (no storage of tuples or other application data). The computation is just counter increment and message dispatch (no transaction execution or searches). A transaction requires just one message (possibly with many recipients) to pass through the sequencer. The message sequencer can be light and fast.

Nevertheless, this process is a bottleneck. Each message traverses two hops, to and from the sequencer. Each tupelo client must be connected to the sequencer to transact on tuples (aside from local reads).

**Tupelo will always have this limitation.** It is essential to the design of the system. By accepting this cost, we get some benefits, discussed in the next section.

Clients may communicate other data over side channels that do not go through the sequencer. For [example](example/socket-broker.rb), they can use the tuplespace to coordinate task assignments, data locations (perhaps external to the tuplespace), TCP hosts and ports, and other metadata, and then use direct connections for the data. The archiver, which is a special client that brings newly connected clients up to date, is another example of direct client-to-client connections.

Other limitations
-----------------

The message sequencer is also a SPoF (single point of failure), but this is not inherent in the design. A future version of tupelo will have options for failover or clustering of the sequencer, perhaps based on [raft](http://raftconsensus.github.io), with a cost of increased latency and complexity. (However, redundancy and failover of *application* data and computation *is* supported by the current implementation; app data and computations are distributed among the client processes.)

There are some limitations that may result from naive application of tupelo: high client memory use, high bandwidth use, high client cpu use. These resource issues can often be controlled with [subspaces](doc/subspace.md) and specialized data structures and data stores. There are several examples addressing these problems. Another approach is to use the tuplespace for low volume references to high volume data.

Also, see the discussion in [transactions](doc/transactions.md) on limitations of transactions across subspaces. It's likely that these limitations will soon be lifted, at the cost of increased latency (only for cross-subspace transactions).

This implementation is also limited in efficiency because of its use of Ruby.

Finally, it must be understood that work on tupelo is still in early, experimental stages. **The tupelo software should not yet be relied on for applications where failure resistance and recovery are important.** The current version is suited for things like batch processing (especially complex dataflow topologies), which can be restarted after failure, or other distributed systems that have short lifespans or are disposable.


Benefits
========

As noted above, the sequencer assigns an incrementing sequence number, or *tick*, to each transaction and dispatches it to the clients, who take on all the burden of tuple computation and storage. This design choice leads to:

* strong consistency: all clients have the same view of the tuplespace at a given tick of the global clock;

* deterministic transaction execution across processes: transactions complete in two network hops, and transactions reference concrete tuples, not templates or queries that require further searching;

* high concurrency: no interprocess locking or coordination is needed to prepare or execute transactions;

* efficient distribution of transaction workload off of the critical path: transaction preparation (finding matching tuples) is performed by just the client initiating the transaction, and transaction execution is performed only by clients that subscribe to subspaces relevant to the transaction;

* client-side logic within transactions: any client state can be accessed while preparing a transaction, and each client is free to use any template and search mechanism (deterministic or not), possibly taking advantage of the client's specialized tuple storage;

* zero-latency reads: clients store subscribed tuples locally, so searching and waiting for matching tuples are local operations;

* relatively easy data replication: all subscribers to a subspace replicate that subspace, possibly with different storage implementations;

* even though storage is distributed, the client programming model is that all tuples are in the same place at the same time; there is no need to reason about multiple clocks or clock skew;

* the current state of the tuplespace can be computed from an earlier state by replaying the transactions in sequence;

* the evolution of system state over time is observable, and tupelo provides the tools to do so: the `--trace` switch, the `#trace` api, and the `tspy` program.

Additional benefits (not related to message sequencing) include:

* the `tup` program for interactively starting and connecting to tupelo instances;

* a framework for starting and controlling child and remote processes connected to the tuplespace;

* options to tunnel connections over ssh and through firewalls, for running in public clouds and other insecure environments;

* choice of object serialization method (msgpack, json, marshal, yaml);

* choice of UNIX or TCP sockets.

Process control and tunneling are available independently of tupelo using the easy-serve gem.


Examples
========

Distributed processing
----------------------

This program counts prime numbers in an interval by distributing the problem to a set of hosts:

    require 'tupelo/app/remote'

    hosts = %w{itchy scratchy lisa bart} # ssh hosts with key-based auth

    Tupelo.tcp_application do
      hosts.each do |host|
        remote host: host, passive: true, eval: %{
          require 'prime' # ruby stdlib for prime factorization
          loop do
            _, input = take(["input", Integer])
            write ["output", input, input.prime_division]
          end
        }
      end

      local do
        inputs = 1_000_000_000_000 .. 1_000_000_000_200

        inputs.each do |input|
          write ["input", input]
        end

        count = 0
        inputs.size.times do |i|
          _, input, factors = take ["output", Integer, nil]
          count += 1 if factors.size == 1 and factors[0][1] == 1
          print "\rChecked #{i}"
        end

        puts "\nThere are #{count} primes in #{inputs}"
      end
    end

Ssh is used to set up the remote processes. Additionally, with the `--tunnel` command line argument, all tuple communication is tunneled over ssh. More examples like this are in [example/map-reduce](example/map-reduce), [example/pregel](example/pregel), and [example/parallel.rb](example/parallel.rb).

Distributed storage
-------------------

Here's an example that creates an in-memory sqlite in one client with a table for Points of Interest (POI). A second client populates that table by writing POI tuples and then executes a SQL delete by writing a tuple with the deletion parameters.

    require 'tupelo/app'
    require_relative 'poi-client' # run this in example/sqlite

    Tupelo.application do
      local do
        POISPACE = PoiStore.define_poispace(self)
        define_subspace("cmd", {id: nil, cmd: String, arg: nil})
        define_subspace("rsp", {id: nil, result: nil})
      end

      child PoiClient, poispace: POISPACE, subscribe: "cmd", passive: true do
        loop do
          req = take subspace("cmd")
          case req[:cmd]
          when "delete box"
            lat = req[:arg][:lat]; lng = req[:arg][:lng]
            template = PoiTemplate.new(poi_template: subspace("poi"),
              lat: lat[0]..lat[1], lng: lng[0]..lng[1])
            deleted = []
            transaction do
              while poi = take_nowait(template)
                deleted << poi
              end
            end
            write id: req[:id], result: deleted
          end
        end
      end

      child subscribe: "rsp" do
        write lat: 1.2, lng: 3.4, desc: "foo"
        write lat: 5.6, lng: 7.8, desc: "bar"
        write lat: 1.3, lng: 3.5, desc: "baz"

        write id: 1, cmd: "delete box", arg: {lat: [1.0, 1.4], lng: [3.0, 4.0]}
        rsp = take id: 1, result: nil
        log "deleted: #{rsp["result"]}"
      end
    end

The output should be something like this:

    A: client 3: deleted: [{"lat"=>1.2, "lng"=>3.4, "desc"=>"foo"}, {"lat"=>1.3, "lng"=>3.5, "desc"=>"baz"}]

See [example/sqlite](example/sqlite) for the complete example. More advanced versions of this example have remote, replicated sqlites for redundancy and load distribution.

Web app coordination
--------------------

This example runs several sinatra web apps and uses tupelo to set up a chat network between their users.

    require 'tupelo/app'
    require 'sinatra/base'

    Tupelo.application do
      [9001, 9002, 9003].each do |port|
        child do |client|
          Class.new(Sinatra::Base).class_eval do
            post '/send' do
              client.write ["message", params["dest"], params["text"]]
            end

            get '/recv' do
              "%s for %s: %s\n" %
                (client.take ["message", params["dest"], String])
            end

            set :port, port
            run!
          end
        end
      end
    end

You can use curl to chat:

    $ curl 'localhost:9001/send?text=hello&dest=fred' -d ''

and

    $ curl 'localhost:9003/recv?dest=fred'
    message for fred: hello

Note that the `recv` call waits for a message if none is available.

See also [example/multi-tier](example/multi-tier) and the chat server in [example/chat](example/chat).


Development
===========

Patches and bug reports are most welcome.

This project is hosted at https://github.com/vjoel/tupelo

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

* nio4r (optional dependency of funl)

Optional gems for some of the examples:

* sinatra, json, http, sequel, sqlite, rbtree, leveldb-native, lmdb

Contact
=======

Joel VanderWerf, vjoel@users.sourceforge.net, [@JoelVanderWerf](https://twitter.com/JoelVanderWerf).

License and Copyright
========

Copyright (c) 2013-2014, Joel VanderWerf

License for this project is BSD. See the COPYING file for the standard BSD license. The supporting gems developed for this project are similarly licensed.
