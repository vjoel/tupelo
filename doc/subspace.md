How subspaces work
==================

Introduction
------------

Subspaces are the units of sharding a tuplespace.

A subspace is a subset of a tuplespace defined by a special kind of pattern,
known as a "portable object template". These templates are less expressive than
the [client-side templates] [1], but they are built out of simple, serializable
objects that represent widely available matching constructs. Saying that a
subspace "is defined by" a template means that a tuple belongs to a subspace
because it matches the template, not because it was assigned to the subspace.

A Tupelo client may subscribe to one or more subspaces, or to the entire
tuplespace. A client intending to read or take from a subspace must subscribe to
it. However, any client can write to any subspace even if it is not subscribed.
This design enables decoupled services that encapsulate and manage computational
and data resources as subspaces.

A reference to a subspace (for example, in a subscription request or in a
message) is in terms of a _tag_ rather than the template which defines
membership in the space. A tupelo client assigns tags to each outgoing message
based on subspace membership. This saves the funl message sequencer the work of
matching messages against templates; it simply sends tagged messages to the
sockets that have subscribed to those tags.

Transactions have a major limitation with subspaces. If the set of tuples
mentioned in a transaction crosses a subspace boundary, then the tuples outside
of the boundary must all be writes. This is so that any client can determine the
success of a transaction without further coordination -- no two-phase commit is
needed. This rule has no effect on transactions that contain only writes (and
which always succeed anyway).

More precisely, we check a transaction as follows. For a tuple `t`, define `S_t` to be the set of subspaces that include `t`. A transaction `T` must satisfy these two conditions:

1. All `S_t` must be equal for all `t` appearing in a take or read operation of `T`. Denote this set as `S_T`.

2. If `T` has reads or takes, then for each tuple `w` in a write operation of `T`, `S_w` must be contained in `S_T`.

There are ways to work around this limitation, however. See [example/ramp.rb](example/ramp.rb).

[1]: The ruby object templates used by the ruby tupelo client may include
classes, procs, ranges, regexes, etc.

Subspace metadata
-----------------

Each subspace is associated with some descriptive information, including the
template that defines tuple membership in the subspace, the tag used to
reference the space both in the subscription api and in messages, and a
multicast address (for future use). Each client needs to know the metadata for
all the subspaces it subscribes to and writes to. We could provide this
information to the client as part of its initial configuration, but that would
make dynamic creation of subspaces difficult to do consistently. So, we
synchronize the subspace metadata across clients using the tuplespace itself.

The metadata for a subspace is packaged in a (map) tuple as in this example:

    {
      __tupelo__:   "subspace",
      tag:          "wine",
      addr:         "239.255.42.42",
      template:     [ {value: "wine"},
                      {set: ["red", "white"]},
                      {type: "number"},                  # price
                      {type: "number", range: [0,100]} ] # %alc
    }

Template syntax is explained in the following section. Note the shortcut syntax.

These metadata tuples themselves form a subspace, and the metadata tuple for
that subspace is:

    {
      __tupelo__:   "subspace",
      tag:          "tupelo subspace",
      addr:         "239.255.1.1",
      template:     { __tupelo__: {value: "subspace"},
                      tag:        nil,
                      addr:       nil,
                      template:   nil }
    }

(Note that the tuples in this space are maps rather than lists, but the value
for the _template_ key may be either a map or a list.)

Subspaces can be dynamically defined by writing metadata tuples to the
tuplespace. A client that subscribes to the subspace of metadata tuples updates
its local state so that it can correctly tag its outgoing tuples if they happen
to belong to the new subspace. Since these updates happen via the tuplespace,
the ordering of these updates and other tuplespace transactions is consistent
for all clients.

Portable Object Templates
-------------------------

As explained elsewhere, tuple can be either a list tuple, such as `[1, "foo",
[]` or a map tuple, such as `{a: 2, b: [4, 6]}`.

A template is either a list or a map (i.e. Ruby array or hash), depending on
whether the tuples in the space are list or map tuples. In the list case, the
numerical index in the template corresponds to the index in the list tuple. In
the map case, the key in the map corresponds to the key in the map tuple. A
match requires that the set of indices or keys is the same. So template that is
a list of three things can only match a tuple that is a list of three things. A
template of the form `{a: ..., b: ..., c: ...}` can only match map tuples that
have the keys `a`, `b`, and `c` and no other keys. Indices and keys have no
significance in matching aside from the aforementioned conditions.

The values in the template are also significant in matching. A `nil` value at
some index or key in a template means that the match succeeds for any
corresponding value in the tuple. If the template value is not `nil`, then it
must be a map with keys among:

    value
    set
    type
    range
    regex

Each of the provided key-value pairs must match the tuple value. The meaning of
matching in each case is as follows.

If `value` is present, then the associated value must equal the value in the
tuple.

If `set` is present, then the associated value must include (as a list) the
value in the tuple.

If `type` is present, then the associated value must be `boolean`, `number`, `integer`, `string`, `list`, or `map` and must equal the type of the value in the tuple.

If `range` is present, then range defined by the associated pair must include
the value in the tuple.

If `regex` is present, then the associated value must match the value in the
tuple (which must be a string).

Portable object templates are not intended for fine-grained recognition of
tuples, but for coarsely defined subspaces. POTs must be implementable (with the
same semantics) in all languages that are used to develop clients. This
portability requirement forces the semantics to be fairly weak. Clients may
perform much more sophisticated matching _within_ subspaces, using any native
methods.

For the details of POTs, see the ruby implementation in the object-template gem.

Subspaces and bin/tup
---------------------

The tup client CLI by default runs a client that subscribes to the entire tuplespace. If you wish to connect just to one or more subspaces, see the --help for the options --use-subspaces and --subscribe. For example:

In terminal 1:

    $ tup sv --use-subspaces
    >> define_subspace "foo", [Numeric]
    >> w [1], ["hello"]
    >> ra Array
    => [[1], ["hello"]]

In terminal 2:

    $ tup sv --subscribe foo
    >> ra Array
    => [[1]]

Examples of Subspaces
---------------------

The simplest use is as a pubsub, with the --pubsub option.

A typical use of subspaces is to reduce network traffic and data storage
requirements.

For datasets larger than you want to push to every client.

Clustering, replication, sharding, partitioning.


Subspaces are 

  table of:
    tag | numeric_id | POT
  not specified where you get these, but must be provided to client
    can be hardcoded or shared through some set of tuples
  if shared in tuples
    client api to add/remove subspaces
    client needs to be initialized with the tuplespace location of these tuples
      e.g.: client.subspace_metadata_is_in <template>
      where template is typically a POT
  the numeric id will be used as part of a multicast address in some future version of funl

archiver
--------

  manage table of tags
  dump operation accepts list of tags and uses them to select output
  watches for changes in subspace metadata
  option to subscribe archiver instance to just specified tags

client
------

* start with either a list of metadata tuples (and dynamic prohibited)
  or subscription to the subspace of them

  client api keeps metadata tuples separate from other tuples, so that
  normally you only interact with them through a special api
    worker has separate data structure for them
    they can be written, but not taken [OBSOLETE]

* writes need to attach tags
    normally, do this by POT from subspace metadata
    for speed, can provide them explicitly
      with option to check against POT for debugging
    If the set of tuples mentioned in a transaction crosses a subspace boundary
      then the tuples outside of the boundary must all be writes [TODO]
  subscribe/subspace api
    sub sends coordinated requests to archiver and to funl
    unsub optionally purges unneeded data
* incoming messages
    if message contains unsubscribed tags [TODO]
      must filter out tuples that are not subscribed (these must be writes,
      because of the transaction limitation)


Support from funl
-----------------

The Funl::Client API defines these methods:

    subscribe_all
    subscribe_tags tags
    unsubscribe_all
    unsubscribe_tags tags
    handle_ack ack

These are used by the Tupelo::Client to manage subspaces.

A Funl::Message has a #tags method for assigning tags, which are used by the message sequencer to dispatch messages to subscribers. Also, assigning a tag value of +true+ requests that mseq reflect the message back to the sender (minus payload), so that #write_wait can tell when to stop waiting, for example.





subspaces
  aka tags, channels, multicast addressses
    the following are in 1-1 correspondence
      subspace (inf set of tuples)
      predicate (template in weak sense below)
      tag (readable name)
      numeric tag (0...2**16)
      multicast address
  
  tag mapping is stored in hash tuples
    {
      __tup_meta__:  "subspace",
      tag:          "foo things",
      addr:         "239.255.42.42",
      template:     [ {value: "foo"},
                      nil,
                      {set: ["red", "green"]},
                      {type: "number"},
                      {type: "number", range: [1,100]} ],
      opt:          {} # other app-specified data
    }
    the template is a weak, but portable syntax for matching
      it should be easily compiled into fast matching code/objects
      like a regex for simple data structures
      (should "opt" be replaced by wildcard key?)
  
  every client (even pubsub) must listen for
    {__tup_meta__: "subspace",...} tuples
    OR have this info preconfigured and guaranteed not to change

  client is responsible for attaching all relevant tags to messages
    scan each tuple that is witten or taken against the tag mapping
    must check this condition:
      if t1 is a tuple taken in a transaction that also takes or writes t2
        and S is a space containing t2
        then S contains t1
      this is so that receiver can determine success of transaction without
        further coordination -- no 2PC needed

  if client writes to subspace that it does not also subscribe to
    then must set flag in message so that msg is reflected as ack
