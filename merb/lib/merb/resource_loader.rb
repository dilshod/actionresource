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
        options = (Merb::Plugins.config[:actionresource][:resources] || {}).merge(options)
        belongs_to = dependent(klass, model, options)
        return nil if model.nil?
        model = model && model.to_s.downcase.singularize
        model_options = options[:model] || {}
        #
        paginators = {}
        has_custom_pagination = false
        options.each do |k, v|
          k = k.to_s.downcase
          next unless k[-11..-1] == '_pagination'
          paginators[k[0..-12]] = (options[:pagination] || {}).merge(v)
          has_custom_pagination = true
        end
        paginators['all'] = options[:pagination] if options[:pagination]
        #
        model_name = belongs_to ? "#{belongs_to}.#{model.pluralize}" : "::#{model.camel_case}"


        models_str = ""
#          "if params[:limit].to_i > 0 && (params[:start].to_i > 0 || params[:start] == '0')\n" +
#          "@#{model.pluralize}_count = #{model_name}.count(*[#{(model_options.dup.delete_if{|k, v| k.to_s == 'order'}).inspect}].flatten)\n" +
#          (Merb.orm == :datamapper ?
#            "@#{model.pluralize} = #{model_name}.all(*[#{model_options.inspect}.merge(:limit => params[:limit].to_i, :offset => params[:start].to_i, :order => params[:sort] ? [params[:sort].to_sym.send(params[:dir] == 'DESC' ? :desc : :asc)] : [])].flatten)\n" :
#            "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options.inspect}.merge(:limit => params[:limit].to_i, :offset => params[:start].to_i, :order => params[:sort] ? "#{params[:sort].gsub(/[^\w_\-]+/, '')} #{params[:dir].gsub(/[^DEASCdeasc]+/, '')}" : nil).flatten)\n"
#          ) + "@_paginated = :offset\nreturn\nend\n"

        # extJS support code (grid, filters support) (filters support only for datamapper)
        if Merb.orm == :datamapper
          models_str+= "
            if params[:limit].to_i > 0 && (params[:start].to_i > 0 || params[:start] == '0')
              conds = {}
              (params[:filter] || {}).keys.each do |k|
                filter = params[:filter][k]
                name = filter['field']
                name.send(filter['data']['comparison']) unless filter['data']['comparison'].blank?
                if filter['data']['type'] == 'date'
                  conds[name] = DateTime.strptime(filter['data']['value'], '%m/%d/%Y')
                elsif filter['data']['type'] == 'string'
                  conds[name.to_sym.like] = '%' + filter['data']['value'] + '%'
                else
                  conds[name] = filter['data']['value']
                end
              end
              @#{model.pluralize}_count = #{model_name}.count(*[#{(model_options.dup.delete_if{|k, v| k.to_s == 'order'}).inspect}.merge(conds)].flatten)
              @#{model.pluralize} = #{model_name}.all(*[#{model_options.inspect}.merge(conds).merge(:limit => params[:limit].to_i, :offset => params[:start].to_i, :order => params[:sort] ? [params[:sort].to_sym.send(params[:dir] == 'DESC' ? :desc : :asc)] : [])].flatten)
              @_paginated = :offset
              return
            end
          "
        else
          models_str+= "
            if params[:limit].to_i > 0 && (params[:start].to_i > 0 || params[:start] == '0')
              @#{model.pluralize}_count = #{model_name}.count(*[#{(model_options.dup.delete_if{|k, v| k.to_s == 'order'}).inspect}].flatten)
              @#{model.pluralize} = #{model_name}.find(*[:all, #{model_options.inspect}.merge(:limit => params[:limit].to_i, :offset => params[:start].to_i, :order => params[:sort] ? \"#{params[:sort].gsub(/[^\w_\-]+/, '')} #{params[:dir].gsub(/[^DEASCdeasc]+/, '')}\" : nil).flatten)
              @_paginated = :offset
              return
            end
          "
        end


        if paginators.empty?
          # without any pagination
          models_str+= Merb.orm == :datamapper ? 
            "@#{model.pluralize} = #{model_name}.all(*[#{model_options.inspect}].flatten)" :
            "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options.inspect}])"
        else
          # with pagination
          loader_str = Proc.new do |p|
            if Merb.orm == :datamapper
              <<-eval_str
                @#{model.pluralize}_count = #{model_name}.count(*[#{(model_options.dup.delete_if{|k, v| k.to_s == 'order'}).inspect}].flatten)
                @#{model.pluralize}_pager = ::Paginator.new(@#{model.pluralize}_count, #{p[:per_page] || 10}) do |offset, per_page|
                  #{model_name}.all(*[#{model_options.inspect}.update(:limit => per_page, :offset => offset #{p[:order] ? ', :order => ' + p[:order].inspect : ''})].flatten)
                end
                @#{model.pluralize}_page = @#{model.pluralize}_pager.page(params[:page])
                @#{model.pluralize} = @#{model.pluralize}_page.items
                @_paginated = :page
              eval_str
            else
              <<-eval_str
                @#{model.pluralize}_count = #{model_name}.count(*[#{(model_options.dup.delete_if{|k, v| k.to_s == 'order'}).inspect}])
                @#{model.pluralize}_pager = ::Paginator.new(@#{model.pluralize}_count, #{p[:per_page] || 10}) do |offset, per_page|
                  #{model_name}.find(*[:all, #{model_options.inspect}.update(:limit => per_page, :offset => offset #{p[:order] ? ', :order => ' + p[:order].inspect : ''})])
                end
                @#{model.pluralize}_page = @#{model.pluralize}_pager.page(params[:page])
                @#{model.pluralize} = @#{model.pluralize}_page.items
                @_paginated = :page
              eval_str
            end
          end
          if has_custom_pagination
            models_str+= "case self.content_type"
            models_str+= paginators.collect do |k, p|
              k == 'all' ? "" : "when :#{k}\n#{loader_str.call(p)}"
            end.join("\n")
            if paginators.keys.include?('all')
              models_str+= "else\n#{loader_str.call(paginators['all'])}"
            else
              models_str+= "else\n" +
                (Merb.orm == :datamapper ?
                  "@#{model.pluralize} = #{model_name}.all(*[#{model_options.inspect}].flatten)" :
                  "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options.inspect}])"
                )
            end
            models_str+= "end"
          else
            models_str+= loader_str.call(paginators['all'])
          end
        end
        #
        #new_model = belongs_to ? "@#{model.singularize} = #{model_name}.build(params[:#{model}])" : "@#{model.singularize} = #{model_name}.new(params[:#{model}])"
        model_str = "@#{model.singularize} = #{model_name}.find_by_param(*[params[:id], #{model_options.inspect}]) or raise RecordNotFound"
        #
        str = <<-eval_str
          def load_models
            #{models_str}
          end

          def load_model
            #{model_str}
          end
          private :load_models, :load_model
        eval_str
        #puts "-------------- load models ----------"
        #puts str
        #puts "==========="
        klass.module_eval(str)
        # before filter for model load
        opts = {:only => [:show, :edit, :update, :destroy]}
        opts[:only] = options[:model_only] if options[:model_only]
        if options[:model_except]
          opts[:only] = nil
          opts[:exclude] = options[:model_except]
        end
        klass.send(:before, *[:load_model, opts])
        # before filter for models load
        opts = {:only => :index}
        opts[:only] = options[:models_only] if options[:models_only]
        if options[:models_except]
          opts[:only] = nil
          opts[:exclude] = options[:models_except]
        end
        klass.send(:before, *[:load_models, opts])
        # return [model, models]
        [model.singularize, belongs_to, model_name]
      end

      def resource(klass, model, options)
        options = (Merb::Plugins.config[:actionresource][:resource] || {}).merge(options)
        belongs_to = dependent(klass, model, options)
        return nil if model.nil?
        model = model.to_s.downcase.singularize
        model_options = options[:model] || {}
        # load
        if Merb.orm == :datamapper
          model_name = belongs_to ? "#{belongs_to}.#{model.singularize}" : "::#{model.camel_case}.first"
        else
          model_name = belongs_to ? "#{belongs_to}.#{model.singularize}" : "::#{model.camel_case}.find(:first)"
        end
        #
        model_str = "@#{model.singularize} = #{model_name} or raise RecordNotFound"
        str = <<-eval_str
          def load_model
            #{model_str}
          end
          private :load_model
        eval_str
        #puts "-------------- load models ----------"
        #puts str
        #puts "==========="
        klass.module_eval(str)
        # before filter for model load
        opts = {:only => [:show, :edit, :update, :destroy]}
        opts[:only] = options[:model_only] if options[:model_only]
        if options[:model_except]
          opts[:only] = nil
          opts[:exclude] = options[:model_except]
        end
        klass.send(:before, *[:load_model, opts])
        # return model
        [model.singularize, belongs_to, model_name]
      end

    end
  end
end