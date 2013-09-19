require 'sequel'

class Tupelo::Archiver
  class Persister
    include Enumerable

    attr_reader :dir

    ## options:
    ## time and size thresholds
    ## sync wal
    ## run in fork, at end of pipe, for parallel case
    ### how to read old wal file in recovery case?
    def initialize dir
      @dir = dir
      unless File.directory?(dir)
        raise "not a dir: #{dir.inspect} -- cannot set up persister"
      end
      ### raise unless blobber is msgpack (or json)?
    end
    
    def wal
      @wal ||= begin
        File.open File.join(dir, "wal"), "w"
      end
    end
    
    def db
      @db ||= begin
        db = Sequel.sqlite(:database => File.join(dir, "db"))
        #db.loggers << Logger.new($stderr) ## client.log ?

        db.create_table? :tuples do
          primary_key   :id
          String        :packed,  null: false
          Integer       :count,   null: false
        end

        db.create_table? :subspaces do
          foreign_key   :tuple_id, :tuples, index: true, null: false
          Integer       :tag,     null: false
        end

        db.create_table? :global do # one row
          Integer       :tick
            # starts from 0 when system starts, but
            # we persist it in case of crash while 2 arcs running, to
            # determine which is more correct
          Integer       :next_id
            # internal state to a single arc worker
        end
        
        if db[:global].count == 0
          db[:global] << {tick: 0, next_id: 0}
        end

        db
      end
    end
    
    def each
      db[:tuples].each do |tuple|
        yield tuple
      end
    end
    
    # rec points to linked list (via next_rec_to_save) of
    # recs to flush to db but we don't have to do that for every transaction
    # (configurable)
    def flush rec, next_id, tick
      ## if threshold etc.
      db.transaction do
        while rec
          n = db[:tuples].filter(id: rec.id).update(count: rec.count)
          if n == 0
            db[:tuples].insert(id: rec.id, count: rec.count, packed: rec.packed)
          end
          rec.unmark_to_save
          rec = rec.next_rec_to_save
        end
        db[:global].update(next_id: next_id, tick: tick)
      end
    ## rescue ???
    end
    
    def next_id
      db[:global].first[:next_id]
    end
    
    def clear_excess_zeros
      db[:tuples].filter(count: 0).delete ## limit rows to delete? threshold?
    end
  end
end
