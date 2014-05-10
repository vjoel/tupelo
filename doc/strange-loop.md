# Tuplespaces in the age of distributed databases

Tuplespaces, starting with Linda in the 1980s, took a brave new approach to  coordination of distributed systems. Unlike message passing, RPC, and publish/subscribe, tuplespaces decouple the participants in both space and time, and they abstract coordination logic from the messy business of addressing processes or channels. They do so using a remarkably simple metaphor. Tuples are aggregates of data that float around in a global space; processes can toss new tuples into the space, observe tuples that match a pattern, and remove tuples from the space. This language, with three verbs and lots of nouns, can express many popular forms of concurrency control. So, why haven't tuplespaces caught on outside of certain narrow application domains?

We track down an answer to this question and try to navigate the pitfalls of the original Linda model. This journey leads us into territory that has only recently been mapped out by distributed database researchers. The Calvin project at Yale, for example, takes a new approach to distributed transactions and consistent active replication: Calvin enforces deterministic transaction ordering and moves the consensus step earlier in the transaction pipeline. We'll see how these techniques, and a few others, help solve the tuplespace problems and yield some unexpected benefits.

We'll look at a full-featured and usable prototype, Tupelo, that offers transactions, optimistic concurrency, consistent replication, sharding, pluggable storage subsystems, low latency, and security. The Tupelo protocol can be implemented within any programming language that can talk MessagePack over sockets, so Tupelo has the potential to coordinate a heterogeneous population of programs and databases. Looking at examples, we'll see that Tupelo is a concise and expressive language for distributed computing.

We'll also take a broader view, comparing other models. In a tuplespace-based system, program state is a globally addressable, virtual shared memory. Is this a worthy alternative to the actor model? Isn't global state bad?

# Bio

Joel studied math at Harvard and Berkeley, getting his PhD for work on decompositions of finite algebraic structures. He taught at the University of Louisville and then helped develop a multithreaded C++ object database used in Apple and Netscape software. Back at UC Berkeley, he worked on vehicle automation, communication, control, and safety systems, and on data analysis and simulation of transportation networks. He was co-founder and architect of a start-up for cloud-based sensor data analysis and freeway flow prediction aimed at traffic engineers. Now, working on a distributed temporal database at http://fauna.org, he's rewriting the transaction language and looking for ways to apply ideas from Calvin. In his spare time, he works on his open source projects: Tupelo and RedShift, a simulation framework in Ruby and C that aims to be the open-source Simulink. He can often be found playing in traffic with wheels clamped to his feet.

# Comments

The Tupelo project is BSD-licensed and available at https://github.com/vjoel/tupelo.

For the talk, I plan to draw on the large pool of examples at https://github.com/vjoel/tupelo/tree/master/example, such as map-reduce, pregel, chat server, web app coordination (sinatra), custom stores (the red-black tree and SQLite examples), custom match/search operators using indexes and other data structures, sharding with consistent hashing, and, of course, the dining philosophers. To understand optimistic concurrency and replication, we'll watch the effect of concurrent transactions as they run in two tupelo shells (the `tup` binary), with tracing (`--trace`) turned on in a third terminal.

I'll focus more on the details of Tupelo than Calvin, pointing out the parts where they have something in common.

I will also briefly mention Ruby's Rinda standard library, and my attempts to fix it (https://github.com/vjoel/my-rinda), which led me to develop Tupelo. (Two of the Rinda patches were eventually accepted into Ruby.) Tupelo was developed without knowledge of Calvin; the similarities came to light later.

I'll show how tupelo manages child clients and briefly mention the built-in features for starting remote clients and using ssh tunnels.

I'll explain why I call the current implementation a prototype: first, because it is in ruby, and, second, because it has a single point of failure, so is not highly available. However, that SPoF, which is the message sequencer, can be replaced with a Paxos cluster, just as Calvin does, to increase availability with a latency trade-off. Tupelo and Calvin are both strongly consistent systems and so, by the CAP theorem, cannot compete on availability terms with eventually consistent systems like Dynamo, Riak, Cassandra, and Serf.

Even as a prototype, Tupelo has some possible applications: batch processing with complex dataflow switching and subtask orchestration, for example.

I'll also discuss how to mitigate the potential resource consumption problems of naive use of Tupelo. One technique that Tupelo has built-in support for is subspaces.

## Related talks

I spoke on Tupelo at the SF Distributed Computing meetup:

http://www.meetup.com/San-Francisco-Distributed-Computing/events/153886592

That talk included a live demonstration of Tupelo on a portable 12-core ARM cluster, which was used to speed up the primality testing of a list of numbers.

I will be speaking in June on the Calvin papers (with advice from of one of the authors) at the SF Papers We Love meetup:

http://www.meetup.com/papers-we-love-too/events/171291972

## Other talks

http://confreaks.com/videos/165-rubyconf2009-dsls-code-generation-and-new-domains-for-ruby
