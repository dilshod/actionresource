#
# BootLoader::LoadClasses changed to load controllers before router
#
class Merb::BootLoader::LoadClasses #< Merb::BootLoader
  class << self

    def run
      # process name you see in ps output
      $0 = "merb#{" : " + Merb::Config[:name] if Merb::Config[:name]} : master"

      # Log the process configuration user defined signal 1 (SIGUSR1) is received.
      Merb.trap("USR1") do
        require "yaml"
        Merb.logger.fatal! "Configuration:\n#{Merb::Config.to_hash.merge(:pid => $$).to_yaml}\n\n"
      end

      if Merb::Config[:fork_for_class_load] && !Merb.testing?
        start_transaction
      else
        Merb.trap('INT') do
          Merb.logger.warn! "Reaping Workers"
          reap_workers
        end
      end

      # Load application file if it exists - for flat applications
      load_file Merb.dir_for(:application) if File.file?(Merb.dir_for(:application))

      # Load classes and their requirements for application
      Merb.load_paths.each do |component, path|
        next if path.last.blank? || component.to_s[0..."application".size] != "application"
        load_classes(path.first / path.last)
      end

      # Load classes and their requirements
      Merb.load_paths.each do |component, path|
        next if path.last.blank? || component.to_s[0..."application".size] == "application" || component == :router
        load_classes(path.first / path.last)
      end

      Merb::Controller.send :include, Merb::GlobalHelpers

      nil
    end

  end
end
