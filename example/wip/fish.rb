# This example doesn't work yet because there is no way to indicate that,
# instead of waiting, it would be better to continue searching the tuplespace,
# backtracking around the [Integer, String] tuple that did not have a mate.

require 'tupelo/app'

Tupelo.application do
  2.times do
    child passive: true do # these could be threads in the next child
      loop do
        transaction do
          fish, = take [String]
          write [1, fish]
        end
      end
    end
  end

  2.times do
    child passive: true do
      loop do
        transaction do
          n1, fish  = take([Integer, String]) ## need to iterate on this search
          n2, _     = take([Integer, fish])   ## if this take blocks
          write [n1 + n2, fish]
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
      sleep rand % 0.1
    end

    fishes.each do |fish|
      log take [10, fish]
    end
  end
end
