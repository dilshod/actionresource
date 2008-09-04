#
# Setup:
#  :only - allowed only actions, default: [], [:index, :show, :new, :create, :edit, :update, :destroy]
#  :except - allow actions except, default: [], []
#  :member - additional member actions, default: [], [:show, :edit, :update, :destroy]
#  :collection - additional collection actions, default: [], [:index, :new, :create]
#  :conditions - additional router match conditions, ex: "env.subdomain == 'main'"
#  :restfull - restfull route match, default: true
#  :allowed_method - allowed method (actual only when restfull=false), default: nil
#
#  :path
#  :member_path
#  :new_path (user/new)
#

class Merb::Router::Behavior
  def iterate_resources(resources, object)
    object.constants.each do |const_name|
      c = object.module_eval(const_name)
      next unless c.is_a?(Class) and c.respond_to?(:controller_name) and c.respond_to?(:resource_setup)
      setup = c.resource_setup
      setup[:controller] = c
      setup[:route_weight]||= 0
      setup[:sub_member] = []
      setup[:sub_collection] = []
      #
      path = const_name.snake_case
      path = path[0...-11] if path[-11..-1] == '_controller'
      if setup[:type] == 'resources'
        path = path.singularize
        setup[:path]||= path.pluralize
        setup[:member_path] = (setup[:member_path] || path).to_s
        setup[:new_path]||= "/" + setup[:member_path] + "/new"
      else
        setup[:path]||= path
        setup[:member_path] = (setup[:member_path] || path).to_s
        setup[:new_path]||= "/" + setup[:member_path] + "/new"
      end
      #
      # iterate sub resources
      #
      name = const_name
      name = name[0...-10] if name[-10..-1] == 'Controller'
      names = nil
      if setup[:type] == 'resources'
        name = name.singularize
        names = name.pluralize
      end
      if object.constants.include?(name)
        begin
          c = Object.module_eval("::" + name)
        rescue NameError => ne
        else
          res = []
          iterate_resources(res, c) if c.is_a?(Module)
          res.sort_by{|m| m[:member_path].length + m[:route_weight]}.reverse
          setup[:sub_member] = res
        end
      end
      #
      if !names.nil? && object.constants.include?(names)
        begin
          c = Object.module_eval("::" + names)
        rescue NameError => ne
        else
          res = []
          iterate_resources(res, c) if c.is_a?(Module)
          res.sort_by{|m| m[:member_path].length + m[:route_weight]}.reverse
          setup[:sub_collection] = res
        end
      end
      #
      resources << setup
    end
  end

  def resource_mapping(resource, parent_path)
    if resource[:type] == 'resources'
      parent_m_path, parent_c_path = pl_resources(parent_path, {}, resource[:controller], resource)
      parent_prefix = ActionResource::NamedRoute.make_named_route_for_resources(parent_path, resource[:controller], resource)
    else
      parent_m_path, parent_c_path = pl_resource(parent_path, {}, resource[:controller], resource)
      parent_prefix = ActionResource::NamedRoute.make_named_route_for_resource(parent_path, resource[:controller], resource)
    end
    resource[:sub_member].each do |member|
      resource_mapping(member, parent_m_path)
    end
    resource[:sub_collection].each do |member|
      resource_mapping(member, parent_c_path)
    end
  end

  def build_resources
    resources = []
    iterate_resources(resources, Object)
    resources.sort_by{|m| m[:member_path].length + m[:route_weight]}.reverse
    #
    unless resources.empty?
      resources.each{|resource| resource_mapping(resource, "")}
    else
      default_routes
    end
  end
end
