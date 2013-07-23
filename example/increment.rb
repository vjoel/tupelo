require 'tupelo/app'

N = 5

Tupelo.application do |app|
  N.times do |i|
    app.child do |client|
      client.transaction do |t|
        n, s = t.take [Numeric, String]
        #sleep rand # No race conditions here!
        t.write [n + 1, s + "\n  incremented by client #{i}"]
      end
    end
  end

  app.child do |client|
    client.write [0, "started with 0"]
    n, s = client.take [N, String]
    puts s, "result is #{n}"
  end
end
