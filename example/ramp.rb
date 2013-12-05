# Read-atomic multipartition transactions, as per:
#   http://www.youtube.com/watch?v=_rAdJkAbGls
#
# Tupelo doesn't allow transactions to cross subspace boundaries (except in the
# special case of writes outside of a subspace). We can get around this at the
# application level, with a few extra steps -- this adds latency, but preserves
# effective atomicity from the applications point of view. The main trick (as in
# Bailis's talk) is to use the global_tick of a successful transaction as a
# globally monotonic counter:
#
#    t = transaction {...}
#    tick = t.global_tick
#    write [t, ...]
# 

require 'tupelo/app'

Tupelo.application do

  

end
