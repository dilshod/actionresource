module ActionResource
  module MapperExtension

    def build_resources(*default_options)
      return unless RAILS_ENV
      ApplicationController.default_resource_options = default_options.extract_options!
      #
      def resources_mappings(map, dir, conditions={}, only=nil)
        mappings = []
        Rails.configuration.controller_paths.each do |controllers_path|
          Dir["#{controllers_path}/#{dir}/*_controller.rb"].each do |file|
            controller = eval(file[file.index(controllers_path) + controllers_path.length + 1 .. file.length - ".rb".length - 1].classify)
            next unless controller.respond_to?(:resource_options)
            m = controller.resource_options
            o = { :mapping => m }
            o[:controller] = controller.controller_path
            o[:controller_name] = controller.name.demodulize[0..-11].underscore
            o[:path] = m[:path] || o[:controller_name]
            o[:route_weight] = (m[:route_weight] || 0).to_i
            o[:member_path] = m[:member_path] || o[:controller_name].singularize
            o[:new_path] = m[:new_path]
            o[:members_path] = m[:members_path] || o[:controller_name].pluralize
            o[:model] = ((m[:models] && m[:models][0]) || m[:controller_name]).to_s.downcase.singularize + '_id'
            o[:only] = m[:only].nil? ? only : m[:only]
            o[:conditions] = m[:conditions] || conditions
            o[:collection] = m[:collection].is_a?(Array) ? m[:collection] : [m[:collection]] if m[:collection]
            o[:member] = m[:member].is_a?(Array) ? m[:member] : [m[:member]] if m[:member]
            o[:new] = m[:new].is_a?(Array) ? m[:new] : [m[:new]] if m[:new]
            o[:requirements] = m[:requiremenets]
            mappings << o
          end
        end
        mappings.sort_by{|m| m[:member_path].length + m[:route_weight]}.reverse.each do |mapping|
          map.with_options(:conditions => mapping[:conditions]) do |sub|
            options = mapping
            mapping = options.delete(:mapping)
            path = options[:controller]
            name = options[:controller_name] #path.gsub('/', '_').to_sym
            #
            if mapping[:type] == 'resources'
              resources_mappings(sub, path.pluralize, options[:conditions], mapping[:only])
            end
            unless mapping[:nil_resource]
              sub.send("pl_#{mapping[:type]}", *[name, options]) do |submap|
                resources_mappings(submap, path.singularize, options[:conditions], mapping[:only])
              end
            else
              resources_mappings(map, path.singularize, options[:conditions], mapping[:only])
            end
          end
        end
      end
      resources_mappings(self, "")
    end

  end
end