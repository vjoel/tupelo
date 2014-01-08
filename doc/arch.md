Architecture
============

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

Protocol
--------

Nothing in the protocol specifies local searching or storage, or matching, or notification, or templating. That's all up to each client. The protocol only contains tuples and operations on them (take, write, pulse, read), combined into transactions.

The protocol has two layers. The outer (message) layer is 6 fields, managed by the funl gem, using msgpack for serialization. All socket reads are non-blocking (using msgpack's stream mode), so a slow sender will not block other activity in the system.

One of those 6 fields is a data blob, containing the actual transaction and tuple information. The inner (blob) layer manages that field using msgpack (by default), marshal, json, or yaml. This layer contains the transaction operations. The blob is not unpacked by the server, only by clients.

Each inner serialization method ("blobber") has its own advantages and drawbacks:

* marshal is ruby only, but can contain the widest variation of objects

* yaml is portable and humanly readable, and still fairly diverse, but very inefficient

* msgpack and json (yajl) are both relatively efficient (in terms of packet size, as well as parse/emit time)

* msgpack and json support the least diversity of objects (just "JSON objects"), but msgpack also supports hash keys that are objects rather than just strings.

For most purposes, msgpack is a good choice, so it is the default.

The sending client's tupelo library must make sure that there is no aliasing within the list of tuples (this is only an issue for Marshal and YAML, since msgpack and json do not support references).

