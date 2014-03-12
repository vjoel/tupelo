

Semantics and optimization of simultaneous operations
------

What happens in when a transaction does two operations on the same tuple? For example:

    t = [1,2]

    transaction do
      write t
      take t
    end

    transaction do
      take t
      write t
    end

Two part answer: prepare and execute.

prepare:
  client provides the ordering of ops; this ordering is significant; ops do
    not commute
  each op is prepared independently using currently available tuple state

commit
  optimize away write-take
  resulting ops have no significant ordering 
  preserve programmer's intent
  remote transaction's success should be "same" as prep success

execute:
  ordering use to decide if a transaction executes successfully:
    take
    read
    write (or pulse, put)
  this is actually enough to support all pre-commit orderings
    for example, 
      read-take -> take
    need to prove this algebraically (reductions)

  read before write because:
    tr {w; r} has "read your writes semantics"; the read can be optimized away 
    but tr {r; w} can't be optimized at commit time

  take before write similarly

  take before read
    tr {read; take} is redundant; can be optimized to take
    tr {take; read} has "don't read your takes" semantics



what abt order of pulse?

optimization: pulse

see also tests

Note about utility of tr{take, take, write} and see [example/dedup.rb](example/dedup.rb) and [example/counters](example/counters).
