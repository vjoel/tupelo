require 'tupelo/app'

N = 2 # how many cpus do you want to use for mappers?

Tupelo.application do |app|
  app.child do |client|
    document = "I will not map reduce in class\n" * 10
    lineno = 0
    document.each_line do |line|
      lineno += 1
      client.write ["wc input", lineno, line]
        # Note that tuples should be small, so if the data is large, the line
        # should be a reference, not the actual data.
    end

    results = Hash.new(0)
    lines_remaining = lineno
    results_remaining = 0
    until lines_remaining == 0 and results_remaining == 0 do
      event, *a = client.take [/wc (?:output|done)/, nil, nil]
        # Using a regex is hacky. Better to use an "or" template. See
        # boolean-match.rb. That's not a standard feature yet.
        # Also, in real use it might be better to use hash tuples rather than
        # arrays.
        # See map-reduce-v2.rb.

      case event
      when "wc output"
        word, count = a
        results[word] += count
        results_remaining -= 1
      when "wc done"
        lineno, result_count = a
        lines_remaining -= 1
        results_remaining += result_count
      end
    end

    client.log "results = #{results}"
  end
  
  N.times do |i|
    app.child passive: true do |client|
      client.log.progname = "mapper #{i}"
      
      loop do
        _, lineno, line = client.take ["wc input", Integer, String]

        h = Hash.new(0)
        line.split.each do |word|
          h[word] += 1
        end

        h.each do |word, count|
          client.write ["wc output", word, count]
        end
        client.write ["wc done", lineno, h.size]
      end
    end
  end
end
