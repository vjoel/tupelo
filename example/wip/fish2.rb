# This works, but requires a fix-up step to clean up after a race condition
# during counter initialization.

require 'tupelo/app'

Tupelo.application do
  2.times do
    child passive: true do
      loop do
        transaction do
          fish, _ = take([String])
          n, _ = take_nowait([Integer, fish])
          if n
            write [n + 1, fish]
          else
            write [1, fish] # another process might also write this, so ...
            write ["fixup", fish]
          end
        end
      end
    end
  end

  child passive: true do
    loop do
      transaction do # fix up the two counter tuples
        _, fish = take ["fixup", String]
        n1, _ = take_nowait [Integer, fish]
        if n1
          n2, _ = take_nowait [Integer, fish]
          if n2
            #log "fixing: #{[n1 + n2, fish]}"
            write [n1 + n2, fish]
          else
            write [n1, fish] # partial rollback
          end
        end
      end
    end
  end

  local do
    seed = 3
    srand seed
    log "seed = #{seed}"
    
    fishes = %w{ trout marlin char salmon }

    a = fishes * 10
    a.shuffle!
    a.each do |fish|
      write [fish]
    end

    fishes.each do |fish|
      log take [10, fish]
    end
  end
end
