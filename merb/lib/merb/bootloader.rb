#
# BootLoader::LoadClasses changed to load controllers before router
#
class Merb::BootLoader::LoadClasses #< Merb::BootLoader
  class << self
    # Load all classes inside the load paths.
    def run
      # Add models, controllers, helpers and lib to the load path
      $LOAD_PATH.unshift Merb.dir_for(:model)
      $LOAD_PATH.unshift Merb.dir_for(:controller)
      $LOAD_PATH.unshift Merb.dir_for(:lib)
      $LOAD_PATH.unshift Merb.dir_for(:helper)

      # Load application file if it exists - for flat applications
      load_file Merb.dir_for(:application) if File.file?(Merb.dir_for(:application))

      second = []
      third = []
      Merb.load_paths.each do |component, path|
        next unless path.last && component != :application
        if component.to_s[0..."application".size] == "application"
          load_classes(path.first / path.last)
        elsif component.to_s[0..."router".size] != "router"
          second << path
        else
          third << path
        end
      end

      # Load classes and their requirements
      second.each do |path|
        load_classes(path.first / path.last)
      end

      # now load router
      third.each do |path|
        load_classes(path.first / path.last)
      end

      Merb::Controller.send :include, Merb::GlobalHelpers
    end
  end
end
