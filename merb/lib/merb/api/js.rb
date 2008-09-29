#
# resources :users, :js => {:only => [:login, :full_name]}
#
module ActionResource::Api::JS
  class << self
    def when_ok(controller, model, *args)
      args = args[-1].is_a?(Hash) ? args.pop : {}
      setup = controller.class.resource_setup
      options = Merb::Plugins.config[:actionresource][:js] || {}
      options = options.merge(Merb::Plugins.config[:actionresource]["js_#{controller.action_name}".to_sym] || {})
      options = options.merge(setup[:js]) if setup[:js].is_a?(Hash)
      options = options.merge(setup["js_#{controller.action_name}".to_sym]) if setup["js_#{controller.action_name}".to_sym].is_a?(Hash)
      controller.headers['Content-Type'] = 'text/js'
      if args[:paginated] && args[:count]
        "{total: #{args[:count]}, data: #{model.to_json(*[options])}}"
      else
        model.to_json(*[options])
      end
    end

    def when_error(controller, model, *options)
      controller.headers['Content-Type'] = 'text/js'
      res = {:errors => {}}
      model.errors.to_hash.each do |property, error|
        res[:errors][property] = error
      end
      res.to_json
    end
  end
end
