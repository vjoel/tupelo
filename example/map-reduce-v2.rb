require 'tupelo/app'
require 'tupelo/util/boolean'

N = 2 # how many cpus do you want to use for mappers?

Tupelo.application do |app|
  app.child do |client|
    document = "I will not map reduce in class\n" * 10
    lineno = 0
    document.each_line do |line|
      lineno += 1
      client.write line: line, lineno: lineno
        # Note that tuples should be small, so if the data is large, the line
        # should be a reference, not the actual data.
        # Also, in a complex application you might want to add another
        # key/value pair to avoid collisions (owner: ..., for example).
    end

    results = Hash.new(0)
    lines_remaining = lineno
    results_remaining = 0
    result_template = client.match_any(
      {word: String, count: Integer},
      {lineno: Integer, result_count: Integer}
    )

    until lines_remaining == 0 and results_remaining == 0 do
      result = client.take result_template

      if result["word"]
        results[result["word"]] += result["count"]
        results_remaining -= 1
      elsif result["lineno"]
        lines_remaining -= 1
        results_remaining += result["result_count"]
      else
        log.error "bad keys in result: #{result}"
      end
    end

    client.log "DONE. results = #{results}"
    client.log "Press ^C to exit"
  end
  
  N.times do |i|
    app.child do |client|
      client.log.progname = "mapper #{i}"
      
      loop do
        input = client.take line: String, lineno: Integer

        h = Hash.new(0)
        input["line"].split.each do |word|
          h[word] += 1
        end

        h.each do |word, count|
          client.write word: word, count: count
        end
        client.write lineno: input["lineno"], result_count: h.size
      end
    end
  end
end
