POI -- Points Of Interest
------

This example creates a sqlite db in memory with a table of locations and descriptions of points of interest, and attaches the db to a subspace of the tuplespace.

The first version, [poi.rb](poi.rb), subscribes to the POI subspace and uses the database to accept inserts into the db when other tupelo clients write to the subspace. Keep in mind that a client can only read or take tuples from a subspace it subscribes to. So this version isn't very useful yet.

The second version [poi-v2.rb](poi-v2.rb), subscribes to a command subspace, which allows other clients to submit queries by writing tuples. The two commands supported select or delete all points within a specified rectangle.

You can have remote and redundant instances of this, and that can distribute load in handling queries as above. (Note: v3 and v4 are yet to be written.)

See example/subspaces/addr-book.rb for more comments on the command/response subspace pattern.

Dependencies:

    gem install sequel sqlite3

