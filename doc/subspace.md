How subspaces work
==================

Introduction
------------

A subspaces is a subset of a tuplespace defined by a special kind of pattern, known as a "portable object template". These templates are less expressive than other client-side templates (such as the very general ruby object templates), but they can be serialized. A tuple belongs to a subspace because it matches the template, not because it was assigned to the subspace.

A Tupelo client may subscribe to a subspace, and it must subscribe to read and take from the subspace. However, any client can write to any subspace even if it is not subscribed to it. This enables decoupled services that encapsulate and manage subspaces.

Transactions have a major limitation when subspaces are defined. If the set of tuples mentioned in a transaction crosses a subspace boundary, then the tuples ouside of the boundary must all be writes. This is so that any client can determine the success of a transaction without further coordination -- no two-phase commit is needed.

write_wait to unsubscribed subspace

Subspace metadata
-----------------

POT


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

  writes need to attach tags
    normally, do this by POT from subspace metadata
    for speed, can provide them explicitly
      with option to check against POT for debugging
  subscribe/subspace api
    sub sends coordinated requests to archiver and to funl
    unsub optionally purges unneeded data
  incoming messages
    if message contains unsubscribed tags
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

In addition, a Funl::Message has a #tag method for assigning tags.

These are used by the Tupelo::Client to manage subspaces.




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
      __zb_meta__:  "subspace",
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
    {__zb_meta__: "subspace",...} tuples
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
    and if using UDP
      then must set flag in message so that msg is bounced back as ack
    if not using UDP
      flag is needed only if requested by client (write_wait)




