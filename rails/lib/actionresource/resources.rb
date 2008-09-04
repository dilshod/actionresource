module ActionResource
  module Resources
    def resources(*models)
      controller = self
      options = models.extract_options!
      belongs_to, eval_str = ActionResource.resources_loader(models, options)

      new_str = ""
      if belongs_to
        models.each do |model|
          new_str << "@#{model.to_s.downcase.singularize} = #{belongs_to}.#{model.to_s.pluralize}.build(params[:#{model.to_s.singularize}])\n"
        end
      else
        models.each do |model|
          new_str << "@#{model.to_s.downcase.singularize} = ::#{model.to_s.singularize.camelize}.new(params[:#{model.to_s.singularize}])\n"
        end
      end

      # index
      eval_str+= ActionResource.make_action(models, "index")
      # show
      eval_str+= ActionResource.make_action(models, "show")
      # new
      eval_str+= ActionResource.make_action(models, "new", new_str)
      # edit
      eval_str+= ActionResource.make_action(models, "edit")
      # create
      eval_str+= ActionResource.make_action(models, "create", new_str,
        models.empty? ? nil : (
          (models.length == 1 ? "" : models.collect{|m| "@#{m.to_s.downcase.singularize}.valid?"}.join(" & ") + " && ") +
          models.collect{|m| "@#{m.to_s.downcase.singularize}.save"}.join(" && ")
        ),
        "index", "new"
      )
      # update
      eval_str+= ActionResource.make_action(models, "update",
        models.collect{|m| "@#{m.to_s.downcase.singularize}.attributes = params[:#{m.to_s.downcase.singularize}]"}.join("\n"),
        models.empty? ? nil : (
          (models.length == 1 ? "" : models.collect{|m| "@#{m.to_s.downcase.singularize}.valid?"}.join(" & ") + " && ") +
          models.collect{|m| "@#{m.to_s.downcase.singularize}.save"}.join(" && ")
        ),
        "index", "edit"
      )
      # destroy
      eval_str+= ActionResource.make_action(models, "destroy", "",
        models.empty? ? nil : (
          models.collect do |model|
            "@#{model.to_s.downcase.singularize}.destroy"
          end.join(" & ")
        ),
        "index", "show"
      )
      #
      eval_str << ActionResource.resource_options('resources', options, models)
      #
      module_eval(eval_str.join("\n"))
    end
  end
end