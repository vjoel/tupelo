POI -- Points Of Interest
------

This example creates a sqlite db in memory with a table of locations and descriptions of points of interest, and attaches the db to a subspace of the tuplespace.

The process which manages that subspace can now do two things:

1. accept inserts (via write)

2. custom queries, accessed by write to a different subspace, which can result in deletes from the POI space, or other queries.

You can have redundant instances of this, and that will distribute load
in #2 above.

See example/subspaces/addr-book.rb for more comments on the command/response subspace pattern.

Dependencies:

    gem install sequel sqlite3

