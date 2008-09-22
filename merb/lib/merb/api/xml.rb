require 'rexml/document'

module ActionResource::Api::XML
  class << self
    def when_ok(controller, model, *options)
      setup = controller.class.resource_setup
      options = Merb::Plugins.config[:actionresource][:xml] || {}
      options = options.merge(Merb::Plugins.config[:actionresource]["xml_#{controller.action_name}".to_sym] || {})
      options = options.merge(setup[:xml]) if setup[:xml].is_a?(Hash)
      options = options.merge(setup["xml_#{controller.action_name}".to_sym]) if setup["xml_#{controller.action_name}".to_sym].is_a?(Hash)
      controller.headers['Content-Type'] = 'text/xml'
      "<?xml version='1.0' encoding='utf-8'?>" + model.to_xml(*[options])
    end

    def when_error(controller, model, *options)
      controller.headers['Content-Type'] = 'text/xml'
      doc = REXML::Document.new
      root = doc.add_element("error")
      model.errors.to_hash.each do |property, error|
        node = root.add_element(property.to_s)
        node << REXML::Text.new(error.to_s) unless error.nil?
      end
      "<?xml version='1.0' encoding='utf-8'?>" + root.to_s
    end
  end
end
