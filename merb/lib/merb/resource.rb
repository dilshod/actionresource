class ActionResource::Method
  class << self
    def rebuild(controller, action, model, belongs_to, model_name)
      body = []
      add_method(controller, body, "before_" + action)
      add_method_type(controller, body, "before_" + action)
      #
      if model
        if action == 'index'
          body << "  render_resource :ok, @#{model.pluralize}, :paginated => @_paginated, :count => @#{model.pluralize}_count"
        elsif action == 'show' || action == 'edit'
          body << "  render_resource :ok, @#{model}"
        elsif action == 'new'
          body << "  @#{model} = #{model_name}." + (belongs_to ? "build" : "new")
          body << "  render_resource :ok, @#{model}"
        elsif action == 'create'
          body << "@#{model} = #{model_name}." + (belongs_to ? "build" : "new") + "(params[:#{model}])"
          body << "if @#{model}.valid?"
          body << "@#{model}.save"
          add_method(controller, body, "after_" + action)
          add_method_type(controller, body, action)
          body << "  render_resource :ok, @#{model}"
          body << "else"
          add_method(controller, body, action + "_error")
          add_method_type(controller, body, action + "_error")
          body << "  render_resource :error, @#{model}"
          body << "end"
        elsif action == 'update'
          body << "@#{model}.attributes = params[:#{model}]"
          body << "if @#{model}.valid?"
          body << "@#{model}.save"
          add_method(controller, body, "after_" + action)
          add_method_type(controller, body, action)
          body << "  render_resource :ok, @#{model}"
          body << "else"
          add_method(controller, body, action + "_error")
          add_method_type(controller, body, action + "_error")
          body << "  render_resource :error, @#{model}"
          body << "end"
        elsif action == 'destroy'
          body << "  @#{model}.destroy"
          body << "  render_resource :ok, @#{model}"
        end
      else
        body << "render_resource :ok"
      end
      #
      body = "def #{action}\n #{body.join("\n ")}\nend"
      if Merb.env == "development"
        puts "==== Compiled method for #{controller.class.name}.#{action}:"
        puts body
        puts "----------------"
      end
      controller.class.module_eval(body)
    end

    def add_method(controller, body, name)
      return false unless controller.respond_to?(name)
      body << name
      true
    end

    def add_method_type(controller, body, name)
      regexp = Regexp.new("^" + name + "_\\w+$")
      return false unless controller.methods.find{|s| regexp.match(s)}
      body << "send('#{name}_' + content_type.to_s) if respond_to?('#{name}_' + content_type.to_s)"
      true
    end
  end
end

class Merb::Controller
  class << self
    def resource(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      model = args[0].nil? ? nil : args[0].to_s
      #
      model, belongs_to, model_name = ActionResource::Loader.resource(self, model, options)
      #
      options[:type] = 'resource'
      options[:only]||= (options[:model_only] || options[:models_only]) && ((options[:model_only] || []).to_a + (options[:models_only] || []).to_a)
      eval_str = "
        class << self
          def resource_setup; #{options.inspect}; end
        end
        " + (
          (options[:only] || ([:new, :create, :show, :edit, :update, :destroy] + options[:collection].to_a + options[:member].to_a)).to_a.flatten.collect do |action|
            "def #{action}; ActionResource::Method.rebuild(self, '#{action}', #{model.inspect}, #{belongs_to.inspect}, #{model_name.inspect}); #{action}; end"
          end
        ).join("\n")
      module_eval(eval_str)
    end

    def resources(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      model = args[0]
      #
      model, belongs_to, model_name = ActionResource::Loader.resources(self, model, options)
      #
      options[:type] = 'resources'
      eval_str = "
        class << self
          def resource_setup; #{options.inspect}; end
        end
        " + (
          (options[:only] || options[:model_only] || ([:index, :new, :create, :show, :edit, :update, :destroy] + options[:collection].to_a + options[:member].to_a)).to_a.flatten.collect do |action|
            "def #{action}; ActionResource::Method.rebuild(self, '#{action}', #{model.inspect}, #{belongs_to.inspect}, #{model_name.inspect}); #{action}; end"
          end
        ).join("\n")
      module_eval(eval_str)
    end
  end
end
