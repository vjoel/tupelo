archiver
  manage table of tags
  dump operation accepts list of tags and uses them to select output
  watches for changes in subspace metadata
  option to subscribe archiver instance to just specified tags

client
  writes need to attach tags
    normally, do this by POT from subspace metadata
    for speed, can provide them explicitly
      with option to check against POT for debugging
  subscribe/subspace api
    sub sends coordinated requests to archiver and to funl
    unsub optionally purges unneeded data

subspace metadata
  table of:
    tag | numeric_id | POT
  not specified where you get these, but must be provided to client
    can be hardcoded or shared through some set of tuples
  if shared in tuples
    client api to add/remove subspaces
    client needs to be initialized with the tuplespace location of these tuples
      e.g.: client.subspace_metadata_is_in <template>
      where template is typically a POT
