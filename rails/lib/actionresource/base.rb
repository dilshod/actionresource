require 'actionresource/params'
require 'actionresource/loader'
require 'actionresource/resource'
require 'actionresource/resources'
require 'actionresource/attr_resource'
require 'actionresource/api'

class AccessDenied < StandardError
end

module ActionController

  class Base
  protected
    cattr_accessor :default_resource_options

    extend ActionResource::Resource
    extend ActionResource::Resources
    extend ActionResource::AttrResource
    extend ActionResource::ParamsMethod

    def rescue_action(exception)
      return super(exception) if RAILS_ENV != 'production'
      case exception
      when ::AccessDenied
        flash[:error] = "You do not have access to that area."
      when ::ActiveRecord::RecordNotFound
        return render(:nothing => true, :status => 404) if request.format.to_sym == :xml
        flash[:error] = "Sorry can't find that record."
      when ::ActionView::MissingTemplate, ::ActionController::RoutingError
        flash[:error] = "We are sorry, but there is no such page."
        #logger.error "NO SUCH PAGE EXCEPTION: #{exception.inspect}"
        #ExceptionNotifier.deliver_exception_notification(exception, self, request) rescue nil
      else
        return super(exception)
      end
      redirect_to('/')
    end

    def self.access_test_method(*name)
      (name.is_a?(Array) ? name : [name]).each do |n|
        eval(
          <<-eval_str
            def self.#{n}(*args)
              args.unshift(:#{n})
              before_filter(*args)
            end
          eval_str
        )
      end
    end

    def template_exists?(action_name)
      begin
        self.view_paths.find_template(default_template_name(action_name), default_template_format)
        true
      rescue
        false
      end
    end

    def render_resource(action=nil, else_action=nil, else_redirect=nil, &block)
      action ||= params[:action]
      #template_exists?(action)
      return render(:action => action) if template_exists?(action)
      return render(:partial => action) if template_exists?("_" + action.to_s)
      #return render(:action => action) if (e = template_exists?("#{self.class.controller_path}/#{action}")) && (e[-3..-1] != "rjs" || ![:all, :html].include?(request.format.to_sym))
      #return render(:partial => action) if (e = template_exists?("#{self.class.controller_path}/_#{action}")) && (e[-3..-1] != "rjs" || ![:all, :html].include?(request.format.to_sym))
      return render_resource(else_action, nil, else_redirect) if else_action
      redirect_to :action => else_redirect if else_redirect && request.format.to_sym == :html
    end
  end
end
