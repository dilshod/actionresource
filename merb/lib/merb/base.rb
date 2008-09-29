class Symbol
  def to_a
    [self]
  end
end

class ::AccessDenied < Merb::ControllerExceptions::Base; end
class ::RecordNotFound < Merb::ControllerExceptions::Base; end

class Merb::Controller
  provides :js, :xml

  class << self
    #
    # Access test:
    #
    # class Application < Merb::Controller
    #   access_test_method :logged_in_access
    #   def logged_in_access
    #     raise AccessDenied unless logged_in?
    #   end
    # end
    #
    # class Users < Application
    #   logged_in_access :except => :index
    # end
    #
    def access_test_method(*name)
      (name.is_a?(Array) ? name : [name]).each do |n|
        eval(
          <<-eval_str
            def #{n}(*args)
              args.unshift(:#{n})
              before(*args)
            end
          eval_str
        )
      end
    end

    #
    # Global access test:
    #
    # class Application < Merb::Controller
    #   def access_test(permissions)
    #     permissions.each do |p|
    #       return if current_user.permissions.include?(p)
    #     end
    #     raise AccessDenied
    #   end
    # end
    #
    # class Users < Application
    #   access_test :admin_users, :except => [:index, :show]
    # end
    #
    def access_test(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      before(*[options]) {|c| c.access_test(args)}
    end
  end

  def render_resource(state, model=nil, *options)
    # render template if exists
    if !_template_for(self.action_name + (state == :error ? '_error' : ''), self.content_type, self.controller_name)[0].nil?
      return render((self.action_name + (state == :error ? '_error' : '')).to_sym)
    end
    # default redirects and renders for html
    if self.content_type == :html && ['create', 'update', 'destroy'].include?(self.action_name)
      if state == :ok
        return redirect(self.respond_to?(:_index_path) ? _index_path : _show_path)
      else
        return render(self.action_name == 'create' ? :new : :edit)
      end
    end
    # call api for all others
    raise Merb::ControllerExceptions::TemplateNotFound unless model && ActionResource::Api.constants.include?(self.content_type.to_s.upcase)
    options = options[-1].is_a?(Hash) ? options.pop : {}
    api = ActionResource::Api.full_const_get(self.content_type.to_s.upcase)
    api.send("when_#{state}", self, *[model, options])
  end
end
