class ActionResource::NamedRoute
  class << self
    def make_method(name, parent_path, path, action, resource)
      path = "/" + path if !path.empty? && path[0..0] != '/'
      puts "  #{name}_path: #{parent_path}#{path}" if $DEBUG
      resource[:controller].module_eval "def _#{action}_path; #{name}_path; end"
      Merb::Controller.module_eval("
        def #{name}_path(*args)
          opts = {}
          if args[-1].is_a?(Hash)
            args.pop.each do |k, v|
              opts[k.to_s] = v.respond_to?(:to_param) ? v.to_param : v.to_s
            end
          end
          url = \"#{parent_path}#{path}\"
          if url.index('/:')
            ps = []
            url.scan(/\\/:([\\w\\d_]+)/) do |s|
              ps << s
            end
            ps.flatten.reverse.each do |p|
              v = args.pop || opts.delete(p.to_s) || params[p]
              v = v.to_param if v.respond_to?(:to_param)
              url = url.gsub(':' + p, v.to_s)
            end
          end
          # format
          if format = opts.delete('format') || params['format'] && format.to_s != 'html'
            url+= '.' + format.to_s
          end
          # anchor
          if opts.key?('anchor')
            url+= '#' + opts.delete('anchor')
          end
          # parameters
          unless opts.empty?
            ps = []
            opts.each do |k, v|
              ps << k.to_s + '=' + CGI.escape(v.to_s)
            end
            url = url + (ps.empty? ? '' : '?' + ps.join('&'))
          end
          url
        end
        private :#{name}_path

        def #{name}_url(*args)
          opts = args[-1].is_a?(Hash) ? args.pop : {}
          host = opts.delete(:host) || opts.delete('host') || request.env['HTTP_HOST']
          port = opts.delete(:port) || opts.delete('port')
          if subdomain = opts.delete(:subdomain) || opts.delete('subdomain')
            host = host.split('.')
            host = host[-2..-1] if host.size >= 2
            host = ([subdomain] + host).join('.')
          end
          args << opts
          \"http://\#{host}\#{port ? ':' + port : ''}\" + #{name}_path(*args)
        end
        private :#{name}_url
      ")
    end

    def make_named_route_for_resources(parent_path, controller, resource)
      name = controller.controller_name.gsub("_controller/", "")
      name = name[0...-("_controller".length)] if name[name.length-"_controller".length..-1] == "_controller"
      name = name.gsub("/", "_")
      #
      make_method(name.singularize.pluralize, parent_path, resource[:path], :index, resource)
      make_method(name.singularize, parent_path, resource[:member_path] + "/:id", :show, resource)
      make_method("edit_" + name.singularize, parent_path, resource[:member_path] + "/:id/edit", :edit, resource)
      make_method("new_" + name.singularize, parent_path, resource[:new_path][1..-1], :new, resource)
      #
      resource[:collection].to_a.each do |action|
        make_method(name.singularize.pluralize + "_" + action.to_s , parent_path, resource[:path] + "/" + action.to_s, action, resource)
      end
      resource[:member].to_a.each do |action|
        make_method(name.singularize + "_" + action.to_s, parent_path, resource[:member_path] + "/:id" + "/" + action.to_s, action, resource)
      end
    end

    def make_named_route_for_resource(parent_path, controller, resource)
      name = controller.controller_name.gsub("_controller/", "")
      name = name[0...-("_controller".length)] if name[name.length-"_controller".length..-1] == "_controller"
      name = name.gsub("/", "_")
      #
      make_method(name, parent_path, resource[:path], :show, resource)
      make_method("edit_" + name, parent_path, resource[:path] + "/edit", :edit, resource)
      make_method("new_" + name, parent_path, resource[:new_path][1..-1], :new, resource)
      #
      resource[:member].to_a.each do |action|
        make_method(name.singularize + "_" + action.to_s, parent_path, resource[:path] + "/" + action.to_s, :action, resource)
      end
    end
  end
end