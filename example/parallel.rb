# a bit like gnu parallel
# see also https://github.com/grosser/parallel

require 'tupelo/app/remote'

show_steps = !!ARGV.delete("--show-steps")

hosts = ARGV.shift
map = ARGV.slice!(0,3)
reduce = ARGV.slice!(0,4)

abort <<END unless hosts and
  map[0] == "map" and reduce[0] == "reduce" and reduce[3]

  usage: #$0 <ssh-host>,... map <var> <expr> reduce <var> <var> <expr> [<infile> ...]
  
  Input can be provided on standard input or as the contents of the files
  specified in the infile arguments. Writes the result of the last
  reduction to standard output.
  
  If --show-steps is set then intermediate reductions are printed as they
  are computed. If input is stdin at the terminal, then you can see these
  outputs even before you type the EOF character.
  
  Caution: very little argument checking! No robustness guarantees!
  
  Example:
  
    ruby #$0 localhost,localhost map s s.length reduce l1 l2 l1+l2

END

hosts = hosts.split(",")

map_str = <<END
  proc do |#{map[1]}|
    #{map[2]}
  end
END

reducer = eval <<END
  proc do |#{reduce[1]}, #{reduce[2]}|
    #{reduce[3]}
  end
END

Tupelo.tcp_application do
  hosts.each do |host|
    remote host: host, passive: true, log: true, eval: %{
      mapper = #{map_str}
      loop do
        s = take(line: String)["line"]
        output = mapper[s]
        log(mapped: output) if #{show_steps}
        write output: output
      end
    }
  end
  
  child passive: true do
    loop do
      m1, m2 = transaction do # transaction avoids deadlock!
        [take(output: nil)["output"],
         take(output: nil)["output"]]
      end

      # fragile! crash here => can't finish

      output = reducer[m1, m2]
      log reduced: output if show_steps
      
      transaction do
        count = take(count: nil)["count"]
        write count: count - 1
        write output: output
      end
    end
  end

  local do
    write count: 0

    ARGF.each do |line|
      transaction do
        write line: line.chomp
        count = take(count: nil)["count"]
        write count: count + 1
      end
    end
    
    read count: 1
    result = take output: nil
    log result if show_steps
    puts result["output"]
  end
end
