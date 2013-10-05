# port of pregel.py (not distributed)

class Vertex
  attr_reader :id, :value, :active, :superstep
  attr_accessor :out_vertices
  attr_reader :incoming_messages, :outgoing_messages
  
  def initialize id, value, out_vertices
    @id = id
    @value = value
    @out_vertices = out_vertices
    @incoming_messages = []
    @outgoing_messages = []
    @active = true
    @superstep = 0
  end
  
  def next_superstep
    @superstep += 1
    @incoming_messages = []
  end
end

class Pregel
  attr_reader :vertices, :num_workers, :partition

  def initialize vertices, num_workers
    @vertices = vertices
    @num_workers = num_workers
    @partition = nil
  end
  
  def run
    @partition = partition_vertices
    while check_active
      superstep
      redistribute_messages
    end
  end
  
  # returns {0 => [vertex,...],.... (num_workers-1) => [...]}
  def partition_vertices
    vertices.group_by {|vertex| worker(vertex)}
  end
  
  def worker vertex
    vertex.hash % num_workers
  end
  
  def superstep
    workers = []
    partition.each_value do |vertex_list|
      workers << Worker.new(vertex_list)
    end

    workers.each do |worker|
      worker.join
    end
  end

  def redistribute_messages
    vertices.each do |vertex|
      vertex.next_superstep
    end
    
    vertices.each do |vertex|
      vertex.outgoing_messages.each do |receiving_vertex, message|
        receiving_vertex.incoming_messages << [vertex, message]
      end
    end
  end

  def check_active
    vertices.any? {|vertex| vertex.active}
  end
end

class Worker
  attr_reader :vertices

  def initialize vertices
    @vertices = vertices
    @thread = Thread.new {run}
    @thread.abort_on_exception = true
  end
  
  def join
    @thread.join
  end

  def run
    superstep
  end

  def superstep
    vertices.each do |vertex|
      if vertex.active
        vertex.update
      end
    end
  end
end
