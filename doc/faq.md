FAQ about tupelo
---

Utility
=======

1. What is tupelo not good for?

  - high availability, large scale systems
  
  - high volume stream data
  
  - applications that cannot accept a SPoF

2. What is tupelo good for? What are the "use cases"?

  - read scaling out (redundant array of sqlite example)
  
  - process coordination of complex background job
  
  - lightweight coordination: when you need task queues or other mechanisms
    and you don't want to run a standalone queue server

Is tupelo a database?

  No. It's really more of a middleware. Tupelo doesn't have its own disk storage, indexing, queries, etc. It depends on other programs to provide these. That's actually a strength, since you can use different storage backends for different cases (subspaces, for example).


Tuplets
=======


General
=======

1. Why "tupelo"?

    Resonance with "tuple", I guess... Also, I'm a fan of Uncle Tupelo.

2. 
