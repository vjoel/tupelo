POI -- Points Of Interest
------

This example creates a sqlite db in memory with a table of locations and descriptions of points of interest, and attaches the db to a subspace of the tuplespace.

The first version, [poi.rb](poi.rb), runs a client that subscribes to the POI subspace and uses the database to accept inserts into the db when other tupelo clients write to the subspace. Keep in mind that a client can only read or take tuples from a subspace it subscribes to. Only the POI subscribers actually get to play with the POI data. So this version isn't very useful.

The second version [poi-v2.rb](poi-v2.rb), runs a client that subscribes not only to the POI subspace but also to a command subspace, which allows other clients to submit queries by writing tuples and to receive responses. Two commands are supported: select or delete all points within a specified rectangle.

You can have remote instances and redundant, replicated instances of the POI client. These instances can distribute load in handling queries as above. (Note: v3 and v4 are yet to be written.)

See [addr-book.rb](../subspaces/addr-book.rb) for more comments on the command/response subspace pattern.

See [example/riemann](example/riemann) for more database-tuplespace interface examples.
 
Dependencies:

    gem install sequel sqlite3


Using the PoiStore
------------------

For interactive use, you can run a PoiStore in a tup client by starting it using the `tup --store` switch.

First, we'll need to start up the tupelo services and define the subspace. Open a terminal in the tupelo dir (or adjust paths accordingly) and:

    $ tup sv
    >> define_subspace "poi", lat:  Numeric, lng:  Numeric, desc: String
    >> write lat: 1.2, lng: 3.4, desc: "foo"

The `-I` and `-r` switches are more or less as for ruby itself (but the space before the argument is required).

Second, in another terminal, we run a client that subscribes to the poi space and stores the pois in a PoiStore.

    $ tup sv -I example/sqlite -r poi-store --symbol-keys --subscribe poi --store PoiStore,poi
    >> ra
    => [{:lat=>1.2, :lng=>3.4, :desc=>"foo"}]

The `--symbol-keys` is so that the adapter between tupelo and sqlite simply passes the hashes with symbol keys directly through the Sequel layer, without converting from strings.

The `ra` should print the poi (note the symbol keys). Or you could `read subspace("poi")` for the same effect as `read_all`.

Now, you can take, write, and read from either of these tup sessions:

    write lat: 5.6, lng: 7.8, desc: "bar"
    write lat: 1.3, lng: 3.5, desc: "baz"

What makes the PoiStore session special is that you can use a `PoiTemplate` for efficient queries using the sqlite indexes. In this example, there are indexes on lat and lng (but not a spatial index, since the sqlite gem doesn't support that out of the box).

    >> pt = PoiTemplate.new subspace("poi"), lat: 1.0 .. 1.4, lng: 3.0 .. 4.0
    >> read_all pt
    => [{:lat=>1.2, :lng=>3.4, :desc=>"foo"}, {:lat=>1.3, :lng=>3.5, :desc=>"baz"}]

You can (unsafely) access the tuplestore itself:

    >> worker.tuplestore

This allows you to directly explore the sqlite tables using the sequel API. But be aware that the worker doesn't expect other threads to directly access the tuplestore, so this should only be used for exploration and debugging.
