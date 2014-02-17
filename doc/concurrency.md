a transaction that is open in a client does not affect other threads or processes using the tuplespace; flip side: not protected; the point of the tracactioj si to guarantess that, at the tick when it successfully executes, all the assumptions made are still valid ...

the mseq is single threaded, but state/computation is small, so ok

clients have high concurrency

two clients can be workign on different requests at same time

two threads in one client similarly
