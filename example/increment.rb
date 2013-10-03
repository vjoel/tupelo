require 'tupelo/app'

N = 5

Tupelo.application do
  N.times do |i|
    child do
      transaction do
        n, s = take [Numeric, String]
        #sleep rand # No race conditions here!
        write [n + 1, s + "\n  incremented by client #{i}"]
      end
    end
  end

  child do
    write [0, "started with 0"]
    n, s = take [N, String]
    puts s, "result is #{n}"
  end
end
