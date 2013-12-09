# Factor numbers using remote hosts. Run with --trace to see contention.
# This is more "map" than "map-reduce", though you could aggregate the
# factored numbers, such as by finding the largest prime factor.

require 'tupelo/app/remote'

hosts = ARGV.shift or abort "usage: #$0 <ssh-hostname>,<ssh-hostname>,..."
hosts = hosts.split(",")

Tupelo.tcp_application do
  hosts.each do |host|
    remote host: host, passive: true, eval: %{
      require 'prime' # ruby stdlib for prime factorization
      loop do
        _, input = take(["input", Integer])
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
