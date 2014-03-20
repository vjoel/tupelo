POI -- Points Of Interest
------

This example creates a sqlite db in memory with a table of locations and descriptions of points of interest, and attaches the db to a subspace of the tuplespace.

The first version, [poi.rb](poi.rb), runs a client that subscribes to the POI subspace and uses the database to accept inserts into the db when other tupelo clients write to the subspace. Keep in mind that a client can only read or take tuples from a subspace it subscribes to. Only the POI subscribers actually get to play with the POI data. So this version isn't very useful.

The second version [poi-v2.rb](poi-v2.rb), runs a client that subscribes not only to the POI subspace but also to a command subspace, which allows other clients to submit queries by writing tuples and to receive responses. Two commands are supported: select or delete all points within a specified rectangle.

You can have remote instances and redundant, replicated instances of the POI client. These instances can distribute load in handling queries as above. (Note: v3 and v4 are yet to be written.)

See [addr-book.rb](../subspaces/addr-book.rb) for more comments on the command/response subspace pattern.

See [example/riemann](example/riemann) for more database-tuplespace interface examples.
 
Dependencies:

    gem install sequel sqlite3

