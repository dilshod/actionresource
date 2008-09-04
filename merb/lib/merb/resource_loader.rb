#
# resources :users, :belongs_to => [:department, :organization]
#
#  :belongs_to
#  :model_only - load model for methods
#  :model_except - load model except methods
#  :models_only - load models for methods
#  :models_except - load models except methods
#  :dependent_model_only - load dependent models only for methods
#  :dependent_model_except - load dependent models except methods
#
#  :model - options for model load
#
module ActionResource
  class Loader
    class << self

      def dependent(klass, model, options)
        loader = []
        belongs_to = options[:belongs_to]
        before_model = nil
        belongs_to.to_a.reverse.each do |model|
          model = model.to_s
          if model[0..0] == "#"
            before_model = model[1..-1]
          elsif model[0..0] == "@"
            before_model = model
          else
            model = model.downcase.singularize
            model_name = before_model ? "#{before_model}.#{model.pluralize}" : "::#{model.singularize.camel_case}"
            loader << "@#{model} = #{model_name}.find_by_param(params[:#{model}_id]) or raise RecordNotFound"
            before_model = "@#{model}"
          end
        end
        #
        unless loader.empty?
          str = <<-eval_str
             def load_dependent_models
               #{loader.join("\n")}
             end
             protected :load_dependent_models
           eval_str
          #puts "---------------- dependent -------"
          #puts str
          #puts "==========="
          klass.module_eval(str)
          opts = {}
          opts[:only] = options[:dependent_model_only] if options[:dependent_model_only]
          opts[:exclude] = options[:dependent_model_except] if options[:dependent_model_except]
          klass.send(:before, *[:load_dependent_models, opts])
        end
        before_model
      end

      #
      # :html_pagination => {:per_page => 20, :order => "name"}
      #
      def resources(klass, model, options)
        return "" if model.nil?
        belongs_to = dependent(klass, model, options)
        model = model.to_s.downcase.singularize
        model_options = options[:model] || {}
        #
        paginators = {}
        options.each do |k, v|
          k = k.to_s.downcase
          next unless k[-11..-1] == '_pagination'
          paginators[k[0..-12]] = v
        end
        #
        model_name = belongs_to ? "#{belongs_to}.#{model.pluralize}" : "::#{model.camel_case}"
        if paginators.empty?
          # without any pagination
          models_str = "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options.inspect}])"
        else
          # with pagination
          models_str = "case params[:format].nil? ? :html : params[:format].to_sym" +
          paginators.collect do |k, p|
            <<-eval_str
              when :#{k}
                @#{model.pluralize}_count = #{model_name}.count(*[#{model_options.inspect}])
                @#{model.pluralize}_pager = ::Paginator.new(@#{model.pluralize}_count, #{p[:per_page] || 10}) do |offset, per_page|
                  #{model_name}.find(*[:all, #{model_options.inspect}.update(:limit => per_page, :offset => :offset #{p[:order] ? ', :order => ' + p[:order].inspect : ''})])
                end
                @#{model.pluralize}_page = @#{model.pluralize}_pager.page(params[:page])
            eval_str
          end.join("\n") +
          "else\n" +
            "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options.inspect}])"
          "end"
        end
        #
        model_str = "@#{model.singularize} = #{model_name}.find_by_param(*[params[:id], #{model_options.inspect}]) or raise RecordNotFound"
        #
        str = <<-eval_str
          def load_models
            #{models_str}
          end

          def load_model
            #{model_str}
          end
          protected :load_models, :load_model
        eval_str
        #puts "-------------- load models ----------"
        #puts str
        #puts "==========="
        klass.module_eval(str)
        # before filter for model load
        opts = {:only => [:show, :edit, :update, :destroy]}
        opts[:only] = options[:model_only] if options[:model_only]
        opts[:exclude] = options[:model_except] if options[:model_except]
        klass.send(:before, *[:load_model, opts])
        # before filter for models load
        opts = {:only => :index}
        opts[:only] = options[:models_only] if options[:models_only]
        opts[:exclude] = options[:models_except] if options[:models_except]
        klass.send(:before, *[:load_models, opts])
      end

      def resource(klass, model, options)
        return "" if model.nil?
        belongs_to = dependent(klass, model, options)
        model = model.to_s.downcase.singularize
        model_options = options[:model] || {}
        model_name = belongs_to ? "#{belongs_to}.#{model.singularize}" : "::#{model.camel_case}.find(:first)"
        model_str = "@#{model.singularize} = #{model_name} or raise RecordNotFound"
        str = <<-eval_str
          def load_model
            #{model_str}
          end
          protected :load_model
        eval_str
        #puts "-------------- load models ----------"
        #puts str
        #puts "==========="
        klass.module_eval(str)
        # before filter for model load
        opts = {:only => [:show, :edit, :update, :destroy]}
        opts[:only] = options[:model_only] if options[:model_only]
        opts[:exclude] = options[:model_except] if options[:model_except]
        klass.send(:before, *[:load_model, opts])
      end

    end
  end
end