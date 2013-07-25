module Tupelo::DSL
  module Client
    def transaction *a, &bl
      if bl and bl.arity == 0
        super *a do |t|
          t.instance_eval &bl
        end
      else
        super
      end
    end
  end
  
  module AppBuilder
    def local *a, &bl
      if bl and bl.arity == 0
        super *a do |client|
          client.extend Client
          client.instance_eval &bl
        end
      else
        super
      end
    end

    def child *a, &bl
      if bl and bl.arity == 0
        super *a do |client|
          client.extend Client
          client.instance_eval &bl
        end
      else
        super
      end
    end
  end
  
  def self.application *a, &bl
    if bl and bl.arity == 0
      Tupelo.application *a do |app|
        app.extend AppBuilder
        app.instance_eval &bl
      end
    else
      Tupelo.application *a, &bl
    end
  end
end
