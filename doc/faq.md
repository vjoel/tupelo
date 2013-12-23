FAQ about tupelo
---

Utility
=======

1. What is tupelo not good for?

  - high availability, very large scale systems
  
  - high volume stream data (for low volume stream data, see [chat](example/chat/chat.rb))
  
  - applications that cannot accept a SPoF (though in the future, "SPoF" may be
    reduced to simply a "bottleneck" by replicating the message sequencer)

2. What is tupelo good for? What are the "use cases"?

  - read scaling out (redundant array of sqlite example)
  
  - process coordination of complex background job
  
  - lightweight coordination: when you need task queues or other mechanisms
    and you don't want to run a standalone queue server

3. Is tupelo a database?

  No. It's really more of a middleware. Tupelo doesn't have its own disk storage, indexing, queries, etc. It depends on other programs to provide these. That's actually a strength, since you can use different storage backends for different cases (subspaces, for example).

4. What's really new about tupelo?

  Tupelo combines these ideas:

  - Atomic broadcast/multicast, virtual synchrony

  - Tuplespace operation semantics (write, read, take)

  - Transactions

  All of these are old ideas, but the three together is possibly new.


Tuplespace Operations and Transactions
======================================

1.  Why no update operation?

  Tuples are immutable while in the space. However, you can update by doing #take and #write in a transaction:
    
        transaction do
          _, n = take ["my counter", Integer]
          write ["my counter", n+1]
        end

  Some storage providers may detect this take-write and perform a more efficient update instead.

Apps, Tools, Command-line Interface
===================================

1. Why is there no CLI for a single transaction or operation, like maybe

      tup ... "read [...]"

  This would only make sense for write and pulse ops, not read or take. The
reason is that #read and #take depend on the client being subscribed to the subspace to which the ops apply. Subscribing may involve significant data transfer, depending on the size of the subspace. It is not generally efficient to do this for a single operation. Use bin/tup instead.

Networking: Security, Firewalls, Hostnames
======================

1. How can I run tupelo securely over a public network?

The built-in security mechanism for tupelo is based on ssh for process control and ssh tunnels for data sockets. OpenSSH 6.0 or later is recommended (tupelo has workarounds for earlier versions). Details of the implementation are in the [easy-serve library](https://github.com/vjoel/easy-serve).

But first, if you are working within a single host, just use UNIX sockets, so you can use UNIX permissions to control access within the host and don't have to worry about access from outside the host. The Tupelo.application framework defaults to UNIX sockets in a tmpdir. You can also explicitly request them from the command line for any program based on the framework, such as bin/tup. For example:

      $ tup srv unix /path/to/sock
      
      $ tup srv

If you need TCP networking but want to minimize exposure, you can request that tupelo listen only on localhost:

      $ tup srv tcp localhost

Then, you can connect from other hosts _only_ using ssh tunnels:

      $ tup myhost:path/to/srv --tunnel

Here, myhost is whatever you need to ssh into the first host (it might be username@example.com). The services file at path/to/srv is read using ssh (it doesn't have to be on the same host as the services themselves, but usually is). Then tunnels to those services are set up over the ssh connection. This is client-managed tunneling.

The procedure for server-managed tunneling is different. When a main Tupelo.application process needs to start a remote client that tunnels back to the server, simply pass `tunnel: true` to the #remote call. (In fact, if you pass --tunnel on the command line, the `true` value becomes the default for all #remote clients.) For [example](example/map-reduce/remote-map-reduce.rb).

2. How can I connect clients across private subnets and behind firewalls?

The built-in solution in tupelo is to use ssh tunnels. If the services in the services file are accessible from a host (via tunnels, if necessary), then a tupelo client on that host can share data with other clients (it's a star topology).

3. How should I configure ssh?

Using remotes and tunnels is much easier if you configure ssh to use control sockets to multiplex ssh sessions over a single connection per host pair. The following works well in .ssh/config:

      Host *
        ControlMaster auto
        ControlPath ~/tmp/.ssh/%r@%h:%p
        ControlPersist yes

Note that the dir `~/tmp/.ssh` must exist, so if ~/tmp is periodically cleaned, you might want to create it in your .profile / .bashrc / .zshrc file. You can  also install public ssh keys to avoid typing your password on first connection.


Debugging
=========

1. How can I see what tuples a client is getting?

Use --trace or #notify or just add this thread:

    Thread.new do
      read {|tt| log tt}
    end

and if you want pass a template to #read.

Tuplets
=======


General
=======

1. Why "tupelo"?

    Resonance with "tuple", I guess... Also, I'm a fan of Uncle Tupelo.

2. 
