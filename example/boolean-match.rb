require 'tupelo/app'

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
  app.local do |client|
    tm = client.or [0..2, String], [3..5, Hash]
    
    client.write(
      [0, "a"], [1, {b: 0}], [2, "c"],
      [3, "a"], [4, {b: 0}], [5, "c"]
    ).wait

    client.log client.read_all tm
  end
end
