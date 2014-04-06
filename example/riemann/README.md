Riemann example
===============

A toy implementation of Riemann (http://riemann.io), in several stages of complexity.

This implementation manages streams of events, storing them in a tuplespace and expiring them as specified. The tuplespace is replicated among several client processes. In different clients, the tuplespace is stored in different data structures, depending on needs, including hash, rbtree, and sqlite.

Each version of this example adds progressively more features and efficiency. See comments in each riemann.rb for details.

The higher-level declaration, analysis, and visualization features of the real Riemann are not part of this example. That functionality would be implemented in the consumer processes, as noted in the comments. (There is, however, a minimal http api.)

Running
-------

To run the `v0` example:

    ruby v0/riemann.rb

and similarly for other versions. There are no special command-line arguments (aside from the usual arguments that all Tupelo.application code has, such as `--trace`).

Files
-----

* Common files, used in all versions

  * [event-subspace.rb](event-subspace.rb): defines which tuples are events
  
  * [producer.rb](producer.rb): methods to generate tuples and write them
    from a tupelo client to the event subspace

* [v1/](v1)

  * Each process uses the default store (flat array, yikes!).

  * See comments in [v1/riemann.rb](v1/riemann.rb).

* [v2/](v2)

  * Each process uses a store suitable for its own operations.

  * See comments in [v2/riemann.rb](v2/riemann.rb).


Using the SqliteEventStore
--------------------------

For interactive use, you can run a SqliteEventStore in a tup client by starting it using the `tup --store` switch.

First, we'll need to start up the tupelo services, define the subspace, and run a minimal version of the event producer. Open a terminal in the tupelo dir (or adjust paths accordingly) and:
  
    $ tup sv -I example/riemann -r event-subspace
    >> define_event_subspace
    >> event = {host: "sample.com", service: "my service", state: "ok", time: 12.34, description: "foo bar", tags: ["a", "b"], metric: 0.23, ttl: 0.5, custom: {"aaa" => 42}}
    >> w event
    
The `-I` and `-r` switches are more or less as for ruby itself (but the space before the argument is required).

Second, in another terminal, we run a client that subscribes to the event space and stores the events in a SqliteEventStore.

    $ tup sv -I example/riemann -r v2/sqlite-event-store --symbol-keys --subscribe event --store SqliteEventStore,event
    >> ra

The symbol-keys is so that the adapter between tupelo and sqlite simply passes the hashes with symbol keys directly through the Sequel layer, without converting from strings.

The `ra` should print the event (note the symbol keys). Or you could `read subspace("event")` for the same effect as `read_all`.

Now, you can take, write, and read from either of these tup sessions. What makes the SqliteEventStore session special is that you can use an `EventTemplate` for efficient queries using the sqlite indexes. In this example, there is a composite index on service/host/time.
  
    >> et = EventTemplate.new event_template: subspace("event"), service: "my service"
    >> read et
    => {:host=>"sample.com", :service=>"my service", :state=>"ok", :time=>12.34, :description=>"foo bar", :metric=>0.23, :ttl=>0.5, :tags=>["a", "b"], :custom=>{:aaa=>42}}


Using the OrderedEventStore
---------------------------

The rbtree-based store works much like the sqlite based store, but with (of course) different query parameters and semantics. With the processes as above, try this:

    $ tup sv -I example/riemann -r v2/ordered-event-store --subscribe event --store OrderedEventStore

    >> ot = OrderedEventTemplate.before time: 12.34, ttl: 0.6
    => #<OrderedEventTemplate:0x007f6413472970 @expiration=12.94>
    >> read ot
    => {"host"=>"sample.com", "service"=>"my service", "state"=>"ok", "time"=>12.34, "description"=>"foo bar", "tags"=>["a", "b"], "metric"=>0.23, "ttl"=>0.5, "custom"=>{"aaa"=>42}}

    >> ot = OrderedEventTemplate.before time: 12.34, ttl: 0.4
    => #<OrderedEventTemplate:0x007f64134426f8 @expiration=12.74>
    >>   ra ot
    => []

The significance of the time and ttl parameters is just their sum, which represents the intended expiry time of an event. This value is used as the key in the rbtree.
