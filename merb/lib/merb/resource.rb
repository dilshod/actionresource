class ActionResource::Method
  class << self
    def rebuild(controller, action)
      body = []
      add_method(controller, body, "before_" + action)
      add_method_type(controller, body, "before_" + action)
      #
      #
      add_method(controller, body, "after_" + action)
      add_method_type(controller, body, action)
      #
      body << "render"
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
      ActionResource::Loader.resource(self, model, options)
      #
      options[:type] = 'resource'
      module_eval("
        class << self
          def resource_setup; #{options.inspect}; end
        end
        " + (
          ([:new, :create, :show, :edit, :update, :destroy] + options[:collection].to_a + options[:member].to_a).collect do |action|
            "def #{action}; ActionResource::Method.rebuild(self, '#{action}'); #{action}; end"
          end
        ).join("\n")
      )
    end

    def resources(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      model = args[0]
      #
      ActionResource::Loader.resources(self, model, options)
      #
      options[:type] = 'resources'
      module_eval("
        class << self
          def resource_setup; #{options.inspect}; end
        end
        " + (
          ([:index, :new, :create, :show, :edit, :update, :destroy] + options[:collection].to_a + options[:member].to_a).collect do |action|
            "def #{action}; ActionResource::Method.rebuild(self, '#{action}'); #{action}; end"
          end
        ).join("\n")
      )
    end
  end
end
