Replication
===========

Tupelo uses [state machine replication] (http://en.wikipedia.org/wiki/State%20machine%20replication). This means that every operation is executed on each replica, resulting in equivalent state across replicas. The only case where tupelo serializes an existing tuplespace is when a new client starts up and reads the tuplespace from an archiver.

Replicas of the same subspace do not need to use the same tuple stores. Data structures for retrieval and for data structures for persistence can differ in different client processes. The only common functionality that all stores must implement is tuple insertion and deletion.
