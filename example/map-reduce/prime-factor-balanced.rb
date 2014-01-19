# Modified prime-factor.rb attempts to balance load better. Improvement
# varies--typically around 50% faster with 12 remote hosts.
# The key to balancing load in this case is that all tuples can be
# read in each worker, so the worker doesn't have to guess so much.

require 'tupelo/app/remote'
require 'set'

hosts = ARGV.shift or abort "usage: #$0 <ssh-hostname>,<ssh-hostname>,..."
hosts = hosts.split(",")

Tupelo.tcp_application do
  hosts.each_with_index do |host, hi|
    remote host: host, passive: true, log: true, eval: %{
      require 'prime' # ruby stdlib for prime factorization
      class M
        def initialize nh, hi, excl = []
          @nh, @hi = nh, hi
          @excl = Set.new(excl)
        end
        def === x
          Array === x and
            x[0] == "input" and
            x[1] % @nh == @hi and
            not @excl.include? x[1]
        end
        def exclude *y
          self.class.new @nh, @hi, @excl + y
        end
      end
      my_pref = M.new(#{hosts.size}, #{hi})

      loop do
        txn = transaction
        begin
          _, input = txn.take_nowait(my_pref)
        rescue TransactionFailure => ex
          next
        end

        if input
          begin
            txn.commit
            output = input.prime_division
            Thread.new do
              begin
                txn.wait
              rescue TransactionFailure
                # someone else got it
              else
                write ["output", input, output]
              end
            end
          rescue TransactionFailure
          end
          my_pref = my_pref.exclude input
          next
        end

        begin
          txn.cancel
        rescue TransactionFailure
        end
        break
      end
        
      loop do
        _, input = take(["input", Integer])
        write ["output", input, input.prime_division]
      end
    }
  end

  local do
    t0 = Time.now
    inputs = 1_000_000_000_000 .. 1_000_000_000_200

    inputs.each do |input|
      write ["input", input]
    end

    inputs.size.times do
      _, input, outputs = take ["output", Integer, nil]
      output_str = outputs.map {|prime, exp|
        exp == 1 ? prime : "#{prime}**#{exp}"}.join(" * ")
      log "#{input} == #{output_str}"
    end
    
    t1 = Time.now
    log "elapsed: %6.2f seconds" % (t1-t0)
  end
end
