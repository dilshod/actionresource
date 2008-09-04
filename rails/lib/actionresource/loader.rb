module ActionResource
  #
  # Loaders
  #
  def ActionResource.belongs_to_loader(belongs_to)
    loader = []
    before_model = nil
    (belongs_to.is_a?(Array) ? belongs_to : [belongs_to]).reverse.each do |model|
      next if model.nil?
      model = model.to_s
      if model.starts_with?("#")
        before_model = model[1..model.length]
      elsif model.starts_with?("@")
        before_model = model
      else
        model = model.downcase.singularize
        model_name = before_model ? "#{before_model}.#{model.pluralize}" : "::" + model.classify
        loader << "@#{model} = #{model_name}.find_by_param(params[:#{model}_id]) or raise ActiveRecord::RecordNotFound"
        before_model = "@#{model}"
      end
    end
    #
    str = loader.empty? ? "" :
      <<-eval_str
        def load_dependent_models
          #{loader.join("\n")}
        end
        protected :load_dependent_models
        before_filter :load_dependent_models
      eval_str
    [str, before_model]
  end

  def ActionResource.models_loader(models, belongs_to, options)
    return "" if models.empty?
    options[:rss_pagination] ||= { :order => "id desc" }
    model_options = options[:model].is_a?(Hash) ? options[:model].inspect : (
      options[:model].is_a?(String) ? "{#{options[:model]}}" : "{}"
    )
    #
    # load models (xml, html, rss, ...)
    #
    # :html_pagination => {:per_page => 20, :order => "name"}
    #
    paginators = {}
    options.each do |k, v|
      k = k.to_s.downcase
      next unless k.ends_with?("_pagination")
      paginators[k[0..-12]] = v
    end
    #
    if paginators.empty?
      # without any pagination
      models_str = models.collect do |model|
        model = model.to_s.downcase
        model_name = belongs_to ? "#{belongs_to}.#{model.pluralize}" : "::" + model.classify
        "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options}])"
      end.join("\n")
    else
      # with pagination
      models_str = models.collect do |model|
        model = model.to_s.downcase
        model_name = belongs_to ? "#{belongs_to}.#{model.pluralize}" : "::" + model.classify
        "case request.format.to_sym == :all || !#{paginators.keys.collect{|i|i.to_s}.inspect}.include?(request.format.to_sym.to_s) ? :html : request.format.to_sym\n" +
        paginators.collect do |k, p|
          <<-eval_str
            when :#{k}
              @#{model.pluralize}_count = #{model_name}.count(*[#{model_options}])
              @#{model.pluralize}_pager = ::Paginator.new(@#{model.pluralize}_count, #{p[:per_page] || 10}) do |offset, per_page|
                @#{model.pluralize} = #{model_name}.find(*[:all, #{model_options}.update(:limit => per_page, :offset => offset #{p[:order] ? ', :order => ' + p[:order].inspect : ''})])
              end
              @#{model.pluralize}_page = @#{model.pluralize}_pager.page(params[:#{models.length > 1 ? model.pluralize + '_page' : 'page'}])
          eval_str
        end.join("\n") +
        "else\n" +
          "@#{model.pluralize} = #{model_name}.find(*[:all, #{model_options}])\n" +
        "end"
      end.join("\n")
    end
    #
    # load model
    #
    if models.length > 1
      model_str = models.collect do |model|
        model = model.to_s.downcase
        model_name = belongs_to ? "#{belongs_to}.#{model.pluralize}" : "::" + model.classify
        "@#{model.singularize} = #{model_name}.find_by_param(*[params[:#{model.singularize}_id], #{model_options}]) or raise ActiveRecord::RecordNotFound"
      end.join("\n")
    else
      model = models[0].to_s.downcase
      model_name = belongs_to ? "#{belongs_to}.#{model.pluralize}" : "::" + model.classify
      model_str = "@#{model.singularize} = #{model_name}.find_by_param(*[params[:id], #{model_options}]) or raise ActiveRecord::RecordNotFound"
    end
    #
    <<-eval_str
      def load_models
        #{models_str}
      end
      def load_model
        #{model_str}
      end
      protected :load_models, :load_model
      before_filter :load_models, :only => :index
      before_filter :load_model, :only => [:show, :edit, :update, :destroy] #:except => [ :index, :new, :create ]
    eval_str
  end

  def ActionResource.model_loader(models, belongs_to, options)
    return "" if models.empty? || !belongs_to
    model_str = models.collect do |model|
      "@#{model.to_s.singularize} = #{belongs_to}.#{model.to_s.singularize}"
    end.join("\n")
    #
    <<-eval_str
      def load_model
        #{model_str}
      end
      protected :load_model
      before_filter :load_model, :except => [ :new, :create ]
    eval_str
  end

  def ActionResource.resources_loader(models, options)
    str, belongs_to = ActionResource.belongs_to_loader(options.delete(:belongs_to))
    [belongs_to, [str + ActionResource.models_loader(models, belongs_to, options)]]
  end

  def ActionResource.resource_loader(models, options)
    str, belongs_to = ActionResource.belongs_to_loader(options.delete(:belongs_to))
    [belongs_to, [str + ActionResource.model_loader(models, belongs_to, options)]]
  end

  #
  # Controller Methods
  #
  def ActionResource.before_action(action, before="")
    <<-eval_str

        def #{action}
          request_format_sym = request.format.to_sym
          request_format_sym = :html if request_format_sym == :all
          response.content_type = request.format.to_s unless request_format_sym == :html
          #{before}
          if respond_to?(:before_#{action})
            before_#{action}
            return if performed?
          end
          if respond_to?("before_#{action}_\#{request_format_sym}")
            send("before_#{action}_\#{request_format_sym}")
            return if performed?
          end
    eval_str
  end

  def ActionResource.after_action(model_name, action, condition=nil, else_redirect=nil, else_render_error=nil)
    model_api = unless model_name.blank?
      <<-eval_str
        return if performed?
        send("render_\#{request_format_sym}_api_on_%s", '#{action}', @#{model_name}, @#{model_name}_page, @#{model_name}_pager) if respond_to?("render_\#{request_format_sym}_api_on_%s")
      eval_str
    else
      "#%s-%s"
    end
    if condition
      <<-eval_str
          if #{condition}
            if respond_to?("after_#{action}")
              send("after_#{action}")
              return if performed?
            end
            if respond_to?("#{action}_\#{request_format_sym}")
              send("#{action}_\#{request_format_sym}")
              return if performed?
            end
            render_resource("#{action}", nil, #{else_redirect ? '"' + else_redirect + '"' : 'nil'})
            #{model_api %['ok', 'ok']}
          else
            if respond_to?("after_#{action}_error")
              send("after_#{action}_error")
              return if performed?
            end
            if respond_to?("#{action}_error_\#{request_format_sym}")
              send("#{action}_error_\#{request_format_sym}")
              return if performed?
            end
            render_resource("#{action}_error", #{else_render_error ? '"' + else_render_error + '"' : 'nil'})
            #{model_api %['error', 'error']}
          end
        end

      eval_str
    else
      <<-eval_str
          if respond_to?("after_#{action}")
            send("after_#{action}")
            return if performed?
          end
          if respond_to?("#{action}_\#{request_format_sym}")
            send("#{action}_\#{request_format_sym}")
            return if performed?
          end
          render_resource("#{action}", #{else_redirect ? '"' + else_redirect + '"' : 'nil'}, #{else_render_error ? '"' + else_render_error + '"' : 'nil'})
          #{model_api %['ok', 'ok']}
        end
      eval_str
    end
  end

  def ActionResource.make_action(model_name, action, before="", condition=nil, else_redirect=nil, else_render_error=nil)
    model_name = model_name && (action == 'index' ? model_name[0].to_s.downcase.pluralize : model_name[0].to_s.downcase.singularize)
    [
      ActionResource.before_action(action, before),
      ActionResource.after_action(model_name, action, condition, else_redirect, else_render_error)
    ]
  end

  #
  # Resource options (class method)
  #
  def ActionResource.resource_options(type, options, models)
    options = (ApplicationController.default_resource_options || {}).dup.update(options)
    options[:type] = type
    options[:models] = models
    <<-eval_str
      class << self
        def resource_options
          #{options.inspect}
        end
      end
    eval_str
  end
end