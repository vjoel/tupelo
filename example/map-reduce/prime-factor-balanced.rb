# Modified prime-factor.rb attempts to balance load better. Improvement
# varies--typically around 50% faster with 12 remote hosts.

require 'tupelo/app/remote'

hosts = ARGV.shift or abort "usage: #$0 <ssh-hostname>,<ssh-hostname>,..."
hosts = hosts.split(",")

Tupelo.tcp_application do
  hosts.each_with_index do |host, hi|
    remote host: host, passive: true, eval: %{
      require 'prime' # ruby stdlib for prime factorization
      class M
        def initialize nh, hi
          @nh, @hi = nh, hi
        end
        def === x
          Array === x and
            x[0] == "input" and
            x[1] % @nh == @hi
        end
      end
      my_pref = M.new(#{hosts.size}, #{hi})
      loop do
        _, input =
          begin
            take(my_pref, timeout: 1.0) # fewer fails (5.0 -> none at all)
          rescue TimeoutError
            take(["input", Integer])
          end
        write ["output", input, input.prime_division]
      end
    }
  end

  local do
    t0 = Time.now
    inputs = 1_000_000_000_000 .. 1_000_000_000_050

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
