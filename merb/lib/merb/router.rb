class Merb::Router::Behavior
  def pl_resources(parent_path, parent_conditions, controller, setup)
    actions = setup[:only] ? setup[:only].to_a.map{|a| a.to_sym} :
      [:index, :show, :new, :create, :edit, :update, :destroy]
    actions-= (setup[:except] || []).to_a.map{|a| a.to_sym}
    #
    path = setup[:path].to_s
    path = "/" + path unless path.empty?
    member_path = setup[:member_path].to_s
    member_path = "/" + member_path unless member_path.empty?
    #
    collection_acts = setup[:restfull] != false ?
      {:index => ["", :get], :new => ["/new", :get, setup[:new_path]], :create => ["", :post]} :
      {:index => "", :new => "/" + (setup[:new_path] || "new").to_s, :create => "/create"}
    member_acts = setup[:restfull] != false ?
      {:show => ["", :get], :edit => ["/edit", :get], :update => ["", :put], :destroy => ["", :delete]} :
      {:show => "", :edit => "/edit", :update => "/update", :destroy => "/delete"}
    (setup[:collection] || []).to_a.each do |action|
      if action.is_a?(Array)
        collection_acts[action[0].to_sym] = ["/" + action[0].to_s, action[1].to_sym]
        actions << action[0].to_sym
      else
        collection_acts[action.to_sym] = "/" + action.to_s
        actions << action.to_sym
      end
    end
    (setup[:member] || []).to_a.each do |action|
      if action.is_a?(Array)
        member_acts[action[0].to_sym] = ["/" + action[0].to_s, action[1].to_sym]
        actions << action[0].to_sym
      else
        member_acts[action.to_sym] = "/" + action.to_s
        actions << action.to_sym
      end
    end
    #
    method = (setup[:only_method] || :get).to_sym
    collection_acts.each do |action, options|
      next unless actions.include?(action)
      if options.is_a?(Array) && !options[2]
        p, m = parent_path + path + options[0], options[1]
      elsif options.is_a?(Array) && options[2]
        p, m = parent_path + options[2], options[1]
      else
        p, m = parent_path + path + options, method
      end
      match_options = {:path => %r{^#{p.gsub(/\/\/+/, "/")}(\.:format)?$}, :method => m}
      match_options = match_options.merge(setup[:requirements] || {})
      match(*[match_options]).to(
        :controller => controller.controller_name.to_s, :action => action.to_s
      )
    end
    member_acts.each do |action, options|
      next unless actions.include?(action)
      if options.is_a?(Array)
        p, m = parent_path + member_path + "/:id" + options[0], options[1]
      else
        p, m = parent_path + member_path + "/:id" + options, method
      end
      match_options = {:path => %r{^#{p.gsub(/\/\/+/, "/")}(\.:format)?$}, :method => m}
      match_options = match_options.merge(setup[:member_requirements] || setup[:requirements] || {})
      match(*[match_options]).to(
        :controller => controller.controller_name.to_s, :action => action.to_s
      )
    end
    return [
      parent_path + member_path + "/:#{setup[:model].blank? ? member_path[1..-1] : setup[:model].to_s.singular}_id",
      parent_path + path
    ]
  end

  # singular resource
  def pl_resource(parent_path, parent_conditions, controller, setup)
    actions = setup[:only] ? setup[:only].to_a.map{|a| a.to_sym} :
      [:show, :new, :create, :edit, :update, :destroy]
    actions-= (setup[:except] || []).to_a.map{|a| a.to_sym}
    #
    path = setup[:path].to_s
    path = "/" + path unless path.empty?
    acts = setup[:restfull] != false ?
      {
        :show => ["", :get], :new => ["/new", :get, setup[:new_path]], :create => ["", :post],
        :edit => ["/edit", :get], :update => ["/", :put], :destroy => ["", :delete]
      } : {
        :show => "", :new => "/" + (setup[:new_path] || "new").to_s, :create => "/create",
        :edit => "/edit", :update => "/update", :destroy => "/delete"
      }
    (setup[:member] || []).to_a.each do |action|
      if action.is_a?(Array)
        acts[action[0].to_sym] = ["/" + action[0].to_s, action[1].to_sym]
        actions << action[0].to_sym
      else
        acts[action.to_sym] = "/" + action.to_s
        actions << action.to_sym
      end
    end
    #
    method = (setup[:only_method] || :get).to_sym
    acts.each do |action, options|
      next unless actions.include?(action)
      if options.is_a?(Array) && !options[2]
        p, m = parent_path + path + options[0], options[1]
      elsif options.is_a?(Array) && options[2]
        p, m = parent_path + options[2], options[1]
      else
        p, m = parent_path + path + options, method
      end
      match_options = {:path => %r{^#{p.gsub(/\/\/+/, "/")}(\.:format)?$}, :method => m}
      match_options = match_options.merge(setup[:requirements] || {})
      match(*[match_options]).to(
        :controller => controller.controller_name.to_s, :action => action.to_s
      )
    end
    return [parent_path + path, parent_path + path]
  end
end
