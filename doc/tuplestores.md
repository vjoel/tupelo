Tuple Stores
============

A tuple store is a custom data structures, or data store (possibly persistent), or database (embedded or client-server), which attaches to some subspace of the tuplespace to provide better storage and retrieval of the affected tuples.

Its possible for two clients to subscribe to the same subspace, but use different stores for those tuples.

A tuplestore must have basic insert, delete, and lookup methods, so that it can be used to execute transactions. However, many stores add specialized functionality, like templates for index-based search and a subspace of command tuple for specialized queries.

Basic stores
------------

`Client::SimpleTupleStore`

In-memory store. Simple but inefficient flat array. Used by default for any tupelo program. Fine for small stores, such as when tupelo is being used primarily for distributed concurrency control on a small scale (such as a batch dataflow job).

This implementation is a good reference for the API that a store needs to implement.

`Client::NullTupleStore`

Stores nothing, and can only be used in the special --pubsub mode.

`Archiver::TupleStore`

In-memory store. Simple and efficient hash, but minimal in features (just the inserts, deletes, and lookups required to be a tuplestore, no special search optimizations). Used by default for any tupelo program.

`Archiver::PersistentTupleStore`

Uses sqlite (via Sequel). Used whenever 'bin/tup' or any TupeloApplication (most of the examples) is run with `--persist-dir <dir>` on the command line.

Advanced stores
===============

See examples:

[key-value store](example/multi-tier/kvstore.rb)
[sorted set using rbtree](example/subspaces/sorted-set-store.rb)
[sqlite table](example/sqlite/poi-store.rb)
[sorted set using rbtree](example/riemann/v2/ordered-event-store.rb)
[sqlite table](example/riemann/v2/sqlite-event-store.rb)



----

Important points when developing a new tuple store:

* equality semantics (#equal vs. #==)
