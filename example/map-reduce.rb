require 'tupelo/app'

N = 2 # how many cpus do you want to use for mappers?

Tupelo.application do
  child do
    document = "I will not map reduce in class\n" * 10
    lineno = 0
    document.each_line do |line|
      lineno += 1
      write ["wc input", lineno, line]
        # Note that tuples should be small, so if the data is large, the line
        # should be a reference, not the actual data.
    end

    results = Hash.new(0)
    lines_remaining = lineno
    results_remaining = 0
    until lines_remaining == 0 and results_remaining == 0 do
      event, *a = take [/wc (?:output|done)/, nil, nil]
        # Using a regex is hacky. Better to use an "or" template. See
        # boolean-match.rb.
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

    log "results = #{results}"
  end
  
  N.times do |i|
    child passive: true do
      log.progname = "mapper #{i}"
      
      loop do
        _, lineno, line = take ["wc input", Integer, String]

        h = Hash.new(0)
        line.split.each do |word|
          h[word] += 1
        end

        h.each do |word, count|
          write ["wc output", word, count]
        end
        write ["wc done", lineno, h.size]
      end
    end
  end
end
