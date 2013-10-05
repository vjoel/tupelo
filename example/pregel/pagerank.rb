# port of pagerank.py (not distributed)

require './pregel'
require 'narray'

NUM_WORKERS = 4
NUM_VERTICES = 10

def main
  vertices = NUM_VERTICES.times.map {|j|
    PageRankVertex.new(j, 1.0/NUM_VERTICES, [])}
  create_edges(vertices)
  
  pr_test = pagerank_test(vertices)
  puts "Test computation of pagerank:\n%p" % pr_test
  
  pr_pregel = pagerank_pregel(vertices)
  puts "Pregel computation of pagerank:\n%p" % pr_pregel
  
  diff = pr_pregel - pr_test
  puts "Difference between the two pagerank vectors:\n%p" % diff
  
  norm = Math.sqrt(diff * diff)
  puts "The norm of the difference is: %p" % norm
end

def create_edges vertices
  vertices.each do |vertex|
    vertex.out_vertices = vertices.sample(4)
  end
end

def pagerank_test vertices
  ident = NMatrix.float(NUM_VERTICES, NUM_VERTICES).unit
  g = NMatrix.float(NUM_VERTICES, NUM_VERTICES)

  vertices.each do |vertex|
    num_out_vertices = vertex.out_vertices.size
    vertex.out_vertices.each do |out_vertex|
      g[vertex.id, out_vertex.id] = 1.0/num_out_vertices
        # node reversed dimensions, a funny feature of NArray!
    end
  end

  mp = (1.0/NUM_VERTICES)*NVector.float(NUM_VERTICES).fill!(1)
  return 0.15 * ((ident - 0.85 * g).inverse) * mp
end

def pagerank_pregel vertices
  pregel = Pregel.new(vertices, NUM_WORKERS)
  pregel.run()
  return NVector.to_na(pregel.vertices.map {|vertex| vertex.value})
end

class PageRankVertex < Vertex
  def update
    if superstep < 50
      @value = 0.15 / NUM_VERTICES +
        0.85 * incoming_messages.inject(0.0) {|sum, (vertex, pagerank)|
          sum + pagerank}
      outgoing_pagerank = value / out_vertices.size
      @outgoing_messages = out_vertices.map {|vertex|
        [vertex, outgoing_pagerank]}
    else
      @active = false
    end
  end
end

if __FILE__ ==  $0
  main
end
