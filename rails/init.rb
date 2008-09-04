require 'mapping/resources'
require 'actionresource/base'
require 'actionresource/mapper'
require 'permalink/permalink_generator'
require 'activerecord_ext'

ActionController::Routing::RouteSet::Mapper.send :include,
  ActionResource::MapperExtension
