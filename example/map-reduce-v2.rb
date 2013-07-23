require 'tupelo/app'

N = 2 # how many cpus do you want to use for mappers?
VERBOSE = ARGV.delete "-v"

class Tupelo::Client
  class Or
    attr_reader :templates

    def initialize worker, templates
      @templates = templates.map {|template| worker.make_template(template)}
    end

    def === obj
      templates.any? {|template| template === obj}
    end
  end
  
  def or *templates
    Or.new(worker, templates)
  end
end

Tupelo.application do |app|
  if VERBOSE
    app.child do |client| # a debugger client, to see what's happening
      note = client.notifier
      puts "%4s %4s %10s %s" % %w{ tick cid status operation }
      loop do
        status, tick, cid, op = note.wait
        unless status == :attempt
          s = status == :failure ? "FAILED" : ""
          puts "%4d %4d %10s %p" % [tick, cid, s, op]
        end
      end
    end
  end

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
    result_template = client.or(
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
