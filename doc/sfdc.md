Tupelo[1] is a language-agnostic protocol for distributing both computation and
storage. The semantics is the classic tuplespace operations (read/write/take)
plus transactions and subspaces. The implementation uses an atomic multicast
messaging layer. If you like consistency, determinism, optimistic concurrency,
and low latency, you'll like tupelo, but beware the single point of failure.
We'll look at two examples in ruby: map-reduce and replicated polyglot storage
using LevelDB and SQLite.

[1] https://github.com/vjoel/tupelo
