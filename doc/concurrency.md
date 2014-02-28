a transaction that is open in a client does not affect other threads or processes using the tuplespace; flip side: not protected; the point of the tracactioj si to guarantess that, at the tick when it successfully executes, all the assumptions made are still valid ...

the mseq is single threaded, but state/computation is small, so ok

clients have high concurrency

two clients can be workign on different requests at same time

two threads in one client similarly

Tupelo uses concurrency across replicas/partitions more than multithread concurrency within a replica/partition. The following remarks on Calvin's serial scheduler (one of several) from calvin-ieee13.pdf apply to tupelo:

Like "H-Store/VoltDB ... [tupelo] never allows two transactions to be sent to the storage backend at the same time. However, if data is partitioned across different storage backends, it allows different transactions to be sent to
different storage backends at the same time."
