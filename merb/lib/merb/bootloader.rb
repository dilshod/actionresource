#
# BootLoader::LoadClasses changed to load controllers before router
#
class Merb::BootLoader::LoadClasses #< Merb::BootLoader
  class << self
    # Load all classes inside the load paths.
    def run
      orphaned_classes = []
      # Add models, controllers, and lib to the load path
      $LOAD_PATH.unshift Merb.dir_for(:model)
      $LOAD_PATH.unshift Merb.dir_for(:controller)
      $LOAD_PATH.unshift Merb.dir_for(:lib)

      load_file Merb.dir_for(:application) if File.file?(Merb.dir_for(:application))

      # Require all the files in the registered load paths
      Merb.load_paths.each do |name, path|
        next unless path.last && name != :application && name != :router
        Dir[path.first / path.last].each do |file|
          begin
            load_file file
          rescue NameError => ne
            orphaned_classes.unshift(file)
          end
        end
      end

      if Merb.load_paths.has_key?(:router)
        # now load router
        path = Merb.load_paths[:router]
        Dir[path.first / path.last].each do |file|
          begin
            load_file file
          rescue NameError => ne
            orphaned_classes.unshift(file)
          end
        end
      end

      Merb::Controller.send :include, Merb::GlobalHelpers
      load_classes_with_requirements(orphaned_classes)
    end
  end
end
