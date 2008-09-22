module ActionResource
end

require 'activerecord_ext'
require 'datamapper_ext'

# make sure we're running inside Merb
if defined?(Merb::Plugins)
  require 'merb/base'
  require 'merb/resource'
  require 'merb/resource_loader'
  require 'merb/bootloader'
  require 'merb/router'
  require 'merb/named_route'
  require 'merb/mapping'
  require 'merb/api'

  # Merb gives you a Merb::Plugins.config hash...feel free to put your stuff in your piece of it
  Merb::Plugins.config[:actionresource] = {
    :chickens => false
  }

  Merb::BootLoader.before_app_loads do
    # require code that must be loaded before the application
  end

  Merb::BootLoader.after_app_loads do
    # code that can be required after the application loads
  end

  #Merb::Plugins.add_rakefiles "actionresource/merbtasks"
end
