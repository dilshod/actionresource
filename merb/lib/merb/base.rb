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

  def _call_action(action)
    begin
      catch(:halt) do
        send(action)
      end
    rescue TemplateNotFound
      case action_name.to_sym
      when :update, :create, :destroy
        redirect url(:action => :index)
      else
        raise
      end
    end
  end
end