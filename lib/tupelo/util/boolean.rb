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
  alias match_any or
end

class Tupelo::Client::Transaction
  def or *templates
    client.or *templates
  end
  alias match_any or
end
