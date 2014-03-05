Protocol
========

See also [arch](doc/arch.rb).

Tuples, Operations, Transactions
--------------------------------

Nothing in the protocol specifies local searching or storage, or matching, or notification, or templating. That's all up to each client. (Typically, this will be handled mostly by a worker thread in the client process.) The protocol only contains tuples and operations on them (take, write, pulse, read), combined into transactions.

There is really only one requirement on implementations of the tupelo client protocol. **A client process must be able to decide whether a transaction succeeds or fails, in agreement with all other clients.** (If the client only subscribes to a subspace, then it only needs to decide transactions on that subspace.) To do so, the process must retain enough tuple state to check whether each take or read operation succeeds. How that state is stored (memory or disk, database table or kv store, indexed or not) is up to the client. What access is exposed to the application layer is also undefined (what templates are supported etc.).

Messages
--------

Down the stack from the transaction layer are the message layers. The message protocol has two layers. The outer (message) layer is 6 fields, managed by the funl gem, using msgpack for serialization. All socket reads are non-blocking (using msgpack's stream mode), so a slow sender will not block other activity in the system.

One of those 6 fields is a data blob, containing the actual transaction and tuple information. The inner (blob) layer manages that field using msgpack (by default), marshal, json, or yaml. This layer contains the transaction operations. The blob is not unpacked by the server, only by clients.

Each inner serialization method ("blobber") has its own advantages and drawbacks:

* marshal is ruby only, but can contain the widest variation of objects

* yaml is portable and humanly readable, and still fairly diverse, but very inefficient

* msgpack and json (yajl) are both relatively efficient (in terms of packet size, as well as parse/emit time)

* msgpack and json support the least diversity of objects (just "JSON objects"), but msgpack also supports hash keys that are objects rather than just strings.

For most purposes, msgpack is a good choice, so it is the default.

The sending client's tupelo library must make sure that there is no aliasing within the list of tuples (this is only an issue for Marshal and YAML, since msgpack and json do not support references).

