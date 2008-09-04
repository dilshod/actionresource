module ActionResource
  module Resource
    def resource(*models)
      controller = self
      options = models.extract_options!
      belongs_to, eval_str = ActionResource.resource_loader(models, options)

      new_str = ""
      if belongs_to
        models.each do |model|
          new_str << "@#{model.to_s.downcase.singularize} = (#{belongs_to}.#{model.to_s.singularize} = #{model.to_s.singularize.classify}.new(params[:#{model.to_s.singularize}]))\n"
        end
      else
        models.each do |model|
          new_str << "@#{model.to_s.downcase.singularize} = ::#{model.to_s.singularize.camelize}.new(params[:#{model.to_s.singularize}])\n"
        end
      end

      # show
      eval_str+= ActionResource.make_action(models, "show")
      # new
      eval_str+= ActionResource.make_action(models, "new", new_str)
      # edit
      eval_str+= ActionResource.make_action(models, "edit")
      # create
      eval_str+= ActionResource.make_action(models, "create", new_str,
        !belongs_to && models.empty? ? nil :
          (belongs_to && !models.empty? ? "#{belongs_to}.valid? & " : "") +
          (models.empty? ? "" : (
              (models.length == 1 && !belongs_to ? "" : models.collect{|m| "@#{m.to_s.downcase.singularize}.valid?"}.join(" & ") + " && ") +
              models.collect{|m| "@#{m.to_s.downcase.singularize}.save"}.join(" && ")
            )
          ) +
          (belongs_to && models.length > 0 ? " && #{belongs_to}.save" : "") +
          (belongs_to && models.length == 0 ? "#{belongs_to}.save" : ""),
        "show", "new"
      )
      # update
      eval_str+= ActionResource.make_action(models, "update",
        models.collect{|m| "@#{m.to_s.downcase.singularize}.attributes = params[:#{m.to_s.downcase.singularize}]"}.join("\n"),
        models.empty? ? nil : (
          (models.length == 1 ? "" : models.collect{|m| "@#{m.to_s.downcase.singularize}.valid?"}.join(" & ") + " && ") +
          models.collect{|m| "@#{m.to_s.downcase.singularize}.save"}.join(" && ")
        ),
        "show", "edit"
      )
      # destroy
      eval_str+= ActionResource.make_action(models, "destroy", "",
        models.empty? ? nil : (
          models.collect do |model|
            "@#{model.to_s.downcase.singularize}.destroy"
          end.join(" & ")
        ),
        nil, "show"
      )
      #
      eval_str << ActionResource.resource_options('resource', options, models)
      #
      module_eval(eval_str.join("\n"))
    end
  end
end