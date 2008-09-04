module DataMapper
  class Base
    def self.permalinked_with(key)
      self.module_eval <<-eval_str
        def self.find_by_param *params
          options = params[-1].is_a?(Hash) ? params.pop : {}
          options[:#{key}] = params[0]
          self.find(*[:first, options])
	end

        def to_param
          self.#{key}.to_s
        end
      eval_str
    end
  end
end