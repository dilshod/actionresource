module ActionResource
  module AttrResource
    def attr_resource(*attributes)
      controller = self
      options = attributes.extract_options!
      belongs_to, eval_str = ActionResource.resource_loader(attributes, options)
      raise unless belongs_to

      new_str = ""
      attributes.each do |attribute|
        new_str << "#{belongs_to}.#{attribute} = params[:#{attribute}]\n"
      end

      # show
      eval_str+= ActionResource.make_action(nil, "show")
      # new
      eval_str+= ActionResource.make_action(nil, "new")
      # edit
      eval_str+= ActionResource.make_action(nil, "edit")
      # create
      eval_str+= ActionResource.make_action(nil, "create", new_str,
        "#{belongs_to}.save",
        "show", "new"
      )
      # update
      eval_str+= ActionResource.make_action(nil, "update", new_str,
        "#{belongs_to}.save",
        "show", "edit"
      )
      # destroy
      eval_str+= ActionResource.make_action(nil, "destroy",
        attributes.collect do |attribute|
          "#{belongs_to}.#{attribute} = nil"
        end.join("\n"),
        "#{belongs_to}.save",
        nil, "show"
      )
      #
      eval_str << ActionResource.resource_options('resource', options, attributes)
      #
      module_eval(eval_str.join("\n"))
    end
  end
end