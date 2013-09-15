# A lock using a distributed queue, like the zookeeper lock:
#
# http://zookeeper.apache.org/doc/r3.3.1/recipes.html#sc_recipes_Locks
#
# Like the zk example:
#
# - there is no specialized lock manager process
#
# - there is no thundering herd effect when the head of the queue advances
#
# - queue state is globally visible (and you could add tuples that record
#   which client_id is holding the lock or waiting for it)
#
# Unlike the zk example:
#
# - there is no mechanism for dealing with clients that disappear, either while
#   holding the lock, or while waiting. See example/lease.rb for a solution.

require 'tupelo/app'

N_CLIENT = 3
N_ITER = 3

Tupelo.application do
  local do
    write ["head", nil]
    write ["tail", nil]
  end
  
  N_CLIENT.times do
    child do
      N_ITER.times do |iter|
        my_wait_pos = nil

        transaction do
          _, head = take ["head", nil]
          _, tail = take ["tail", nil]
          if head
            write ["head", head]
            write ["tail", tail + 1]
            my_wait_pos = tail + 1
          else
            write ["head", 0]
            write ["tail", 0]
          end
        end

        if my_wait_pos
          read ["head", my_wait_pos]
        end

        log "working on iteration #{iter}..."
        sleep 0.2
        log "done"

        transaction do
          _, head = take ["head", nil]
          _, tail = take ["tail", nil]
          if head == tail
            write ["head", nil]
            write ["tail", nil]
          else
            write ["head", head + 1]
            write ["tail", tail]
          end
        end
      end
    end
  end
end
