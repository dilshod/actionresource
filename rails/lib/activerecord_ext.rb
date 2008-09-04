module ActiveRecord
  class Base
    def self.permalinked_with(key)
      self.module_eval <<-eval_str
        def self.find_by_param *params
          self.find_by_#{key}(*params)
	end

        def to_param
          self.#{key}.to_s
        end
      eval_str
    end
  end
end