module ActionResource
  class Params
    attr_accessor :index, :parent, :operations

    def [] index
      p = Params.new
      p.parent = self
      self.index = [index, p]
      return p
    end

    def to_s
      return parent.to_s if parent
      i = self.index
      return "params" unless i
      s = "params[#{i[0].inspect}]"
      while i[1].index
        i = i[1].index
        s << "[#{i[0].inspect}]"
      end
      return s + (operations || "")
    end

    def to_i
      self.to_s.to_i
    end
    alias_method :inspect, :to_s
  end

  class LazyEval
    def initialize(str)
      @str = str
    end

    def to_s
      @str
    end
    alias_method :inspect, :to_s
  end

  module ParamsMethod
    def params
      Params.new
    end

    def lazy_eval(str)
      LazyEval.new(str)
    end
  end
end