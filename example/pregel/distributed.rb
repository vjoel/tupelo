# Distributed version of pagerank.rb. This uses only a single host. To use
# many hosts, see remote.rb.

# TODO
#
# Improvements noted in the article.
# Scale better with subspaces and sqlite or other data structure.
# And the subspaces could be defined by consistent hashing and smarter
# partitioning.
# Also, need to handle crashed process and lost tuple (as lease.rb maybe).
# Abstract out domain-specific code from generic framework code.
# Option to compare result with that of pagerank.rb using same seed.

require 'tupelo/app'
require_relative 'update'

NUM_WORKERS = 4
NUM_VERTICES = 10
PRNG_SEED = 1234

Tupelo.application do
  
  NUM_WORKERS.times do |i|
    child passive: true do
      log.progname = "worker #{i}"

      loop do
        step = vertex = nil
        transaction do
          step = read(step: Numeric)["step"]
          vertex = take id: nil, step: step, rank: nil, active: true
          # wait for a vertex to be available on current step, but retry if
          # step changes
        end

        v_me = vertex["id"]
        vs_dst = read_all(src: v_me, dst: nil).map {|h| h["dst"]}
        vs_src = read_all(src: nil, dst: v_me).map {|h| h["src"]}
        
        incoming_messages = transaction do
          vs_src.inject([]) do |ms, v_src|
            while m=take_nowait(src: v_src, dst: v_me, step: step, rank: nil)
              ms << m
            end
            ms
          end
        end

        vertex, outgoing_messages = update(vertex, incoming_messages, vs_dst)
        write vertex, *outgoing_messages
        
        transaction do
          n = take(count: Integer, active: vertex["active"])["count"]
          write count: n + 1, active: vertex["active"]
        end
      end
    end
  end
  
  child do
    log.progname = "coordinator"

    step = 0
    v_ids = (0...NUM_VERTICES).to_a

    v_ids.each do |v_id|
      write id: v_id, step: step, rank: 1.0/NUM_VERTICES, active: true
    end

    srand PRNG_SEED
    v_ids.each do |v_src|
      v_ids.sample(4).each do |v_dst|
        write src: v_src, dst: v_dst
      end
    end

    write count: 0, active: true
    write count: 0, active: false
    loop do
      log "step: #{step}"
      transaction do
        write step: step
        take count: nil, active: true
        write count: 0, active: true
      end
      
      # wait for all vertices to finish step and maybe become inactive
      done = transaction do
        n_active = read(count: nil, active: true)["count"]
        read(count: NUM_VERTICES - n_active, active: false)
        n_active == 0
      end
      
      if done
        vs = read_all(id: nil, step: nil, rank: nil, active: nil)
        log vs.sort_by {|v| v["id"]}.map {|v| v["rank"]}
        exit
      end
      
      take step: step
      step += 1
    end
  end
end
