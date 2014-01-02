# This works, but requires pre-initialization of all counters.

require 'tupelo/app'

Tupelo.application do
  2.times do
    child passive: true do
      loop do
        transaction do
          fish, _ = take([String])
          n, _ = take([Integer, fish])
          write [n + 1, fish]
        end
      end
    end
  end

  local do
    seed = 3
    srand seed
    log "seed = #{seed}"
    
    fishes = %w{ trout marlin char salmon }
    fishes.each do |fish|
      write [0, fish]
    end

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
