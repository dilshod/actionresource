module DataMapper
  module Permalinked
    module ClassMethods
      def permalinked_with(key)
        self.module_eval <<-eval_str
          def self.find_by_param *params
            options = params[-1].is_a?(Hash) ? params.pop : {}
            options[:#{key}] = params[0]
            self.first(*[options].flatten)
          end

          def to_param
            self.#{key}.to_s
          end
        eval_str
      end
   end

    def self.included(model)
      model.extend(ClassMethods)
      model.permalinked_with :id
    end
  end

  Resource.append_inclusions Permalinked
end
