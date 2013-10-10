class Tupelo::Client
  # Simplest fully functional tuplespace. Not efficient for large spaces.
  class SimpleTuplespace < Array
    alias insert <<

    def delete_once elt
      if i=index(elt)
        delete_at i
      end
    end

    def transaction inserts: [], deletes: [], tick: nil
      deletes.each do |tuple|
        delete_once tuple or raise "bug"
      end

      inserts.each do |tuple|
        insert tuple.freeze ## freeze recursively
      end
    end

    def find_distinct_matches_for templates
      templates.inject([]) do |tuples, template|
        tuples << find_match_for(template, distinct_from: tuples)
      end
    end

    def find_match_for template, distinct_from: []
      find do |tuple|
        template === tuple and not distinct_from.any? {|t| t.equal? tuple}
      end
    end
  end
  
  # Tuplespace that stores nothing. Very efficient for large spaces!
  # Useful for clients that don't need to take or read the stored tuples.
  # The write, pulse, and blocking read operations all work correctly.
  # The client is essentially a pub/sub client, then. See the
  # --pubsub switch in tup for an example.
  class NullTuplespace
    include Enumerable
    def each(*); end
    def delete_once(*); end
    def insert(*); self; end
    def find_distinct_matches_for(*); raise; end ##?
    def find_match_for(*); raise; end ##?
    
    ## should store space metadata, so outgoing writes can be tagged
  end
end
