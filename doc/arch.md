Architecture
============

See also [protocol](doc/protocol.md).

Two central processes:

* message sequencer -- assigns unique increasing IDs to each message (a message is essentially a transaction containing operations on the tuplespace). This is the key to the whole design. By sequencing all transactions in a way that all clients agree with, the transactions can be applied (or rejected) by all clients without further negotiation.

* client sequencer -- assigns unique increasing IDs to clients when they join the distributed system

Specialized clients:

* archiver -- dumps tuplespace state to clients joining the system later than t=0; at least one archiver is required, unless all clients start at t=0.

* tup -- command line shell for accessing (and creating) tuplespaces

* tspy -- uses the notification API to watch all events in the space

* queue / lock / lease managers (see examples)

General application clients:

* contain a worker thread and any number of application-level client threads

* worker thread manages local tuplespace state and requests to modify or access it

* client threads construct transactions and wait for results (communicating with the worker thread over queues); they may also use asynchronous transactions

Some design principles:

* Once a transaction has been sent from a client to the message sequencer, it references only tuples, not templates. This makes it faster and simpler for each receiving client to apply or reject the transaction. Also, clients that do not support local template searching (such as archivers) can store tuples using especially efficient data structures that only support tuple-insert, tuple-delete, and iterate/export operations.

* Use non-blocking protocols. For example, transactions can be evaluated in one client without waiting for information from other clients. Even at the level of reading messages over sockets, tupelo uses (via funl and object-stream) non-blocking constructs. At the application level, you can use transactions to optimistically modify shared state (but applications are free to use locking if high contention demands it).

* Do the hard work on the client side. For example, all pattern matching happens in the client that requested an operation that has a template argument, not on the server or other clients.
