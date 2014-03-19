class Tupelo::Archiver
  class PersistentTupleStore
    include Enumerable
    
    attr_reader :zero_tolerance
    
    class Rec
      attr_accessor :id
      attr_accessor :count
      attr_accessor :packed
      
      # linked list of recs to update to db
      attr_accessor :next_rec_to_save
      
      def initialize ts, obj
        @id = ts.next_id
        @count = 0
        @packed = MessagePack.pack(obj)
        @next_rec_to_save = nil
      end
      
      def unmark_to_save
        @next_rec_to_save = nil
      end
    end

    def initialize(
        persist_dir: nil,
        zero_tolerance: Tupelo::Archiver::ZERO_TOLERANCE)

      @next_id = 0
      @tuple_rec = Hash.new {|h,k| h[k] = Rec.new(self, k)}
      @nzero = 0
      @zero_tolerance = zero_tolerance
      @next_rec_to_save = nil

      if persist_dir
        require 'tupelo/archiver/persister.rb'
        @persister = Persister.new persist_dir
        read_from_persister
      else
        @persister = nil
      end
    end

    def read_from_persister
      @persister.each do |tuple_row|
        packed = tuple_row[:packed]
        tuple = MessagePack.unpack(packed)
        rec = @tuple_rec[tuple]
        rec.count = tuple_row[:count]
        rec.id = tuple_row[:id]
        rec.packed = packed
      end
      @next_id = @persister.next_id
      ## @persister.tick # how to send this back to worker? do we need to?
    end

    def next_id
      @next_id += 1
    end
    
    # note: multiple equal tuples are yielded once
    def each
      @tuple_rec.each do |tuple, rec|
        yield tuple, rec.count if rec.count > 0
      end
    end
    
    def mark_to_save rec
      unless rec.next_rec_to_save
        rec.next_rec_to_save = @next_rec_to_save
        @next_rec_to_save = rec
        nil
      end
    end

    def insert tuple
      rec = @tuple_rec[tuple]
      rec.count += 1
      mark_to_save rec if @persister
    end
    
    def delete_once tuple
      rec = @tuple_rec[tuple]
      if rec.count > 0
        rec.count -= 1
        if rec.count == 0
          @nzero += 1
          clear_excess_zeros if @nzero > zero_tolerance
        end
        mark_to_save rec if @persister
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
      
      flush tick
    end

    def flush tick
      if @persister
        @persister.flush(@next_rec_to_save, @next_id, tick)
      end
    end

    def clear_excess_zeros
      nd = (@nzero - zero_tolerance / 2)
      @nzero -= nd
      @tuple_rec.delete_if {|tuple, rec| rec.count == 0 && (nd-=1) >= 0}
      @nzero += nd
      
      @persister.clear_excess_zeros if @persister
    end

    def find_distinct_matches_for tuples
      h = Hash.new(0)
      tuples.map do |tuple|
        if @tuple_rec[tuple].count > h[tuple]
          h[tuple] += 1
          tuple
        else
          nil
        end
      end
    end

    def find_match_for tuple, distinct_from: []
      @tuple_rec[tuple].count > distinct_from.count(tuple)
    end
  end
end
