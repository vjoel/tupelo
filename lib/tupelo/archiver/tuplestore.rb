class Tupelo::Archiver
  # Faster than the default tuplestore, but does not support some things
  # that are not needed in the Archiver: template searches, for example.
  class TupleStore
    include Enumerable
    
    attr_reader :zero_tolerance

    def initialize(zero_tolerance: Tupelo::Archiver::ZERO_TOLERANCE)
      @zero_tolerance = zero_tolerance
      clear
    end
    
    def clear
      @counts = Hash.new(0) # tuple => count
      @nzero = 0
    end
    
    # note: multiple equal tuples are yielded once
    def each
      @counts.each do |tuple, count|
        yield tuple, count if count > 0
      end
    end
    
    def insert tuple
      @counts[tuple] += 1
    end
    
    def delete_once tuple
      if @counts[tuple] > 0
        @counts[tuple] -= 1
        if @counts[tuple] == 0
          @nzero += 1
          clear_excess_zeros if @nzero > zero_tolerance
        end
        true
      else
        false
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

    def clear_excess_zeros
      nd = (@nzero - zero_tolerance / 2)
      @nzero -= nd
      @counts.delete_if {|tuple, count| count == 0 && (nd-=1) >= 0}
      @nzero += nd
    end

    def find_distinct_matches_for tuples
      h = Hash.new(0)
      tuples.map do |tuple|
        if @counts[tuple] > h[tuple]
          h[tuple] += 1
          tuple
        else
          nil
        end
      end
    end

    def find_match_for tuple, distinct_from: []
      @counts[tuple] > distinct_from.count(tuple)
    end
  end
end
