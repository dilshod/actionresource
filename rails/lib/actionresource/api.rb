module ActionController
  class Base
  protected
    #
    # RESTfull api (XML)
    #
    def render_xml_api_on_ok(action, model, page, pager)
      return unless self.class.resource_options[:xml]
      case action
      when 'index', 'show', 'new', 'create', 'update'
        options = self.class.resource_options[action == 'index' ? :xml_all : :xml_one]
        return if options == false
        options = nil if options == true
        options ||= self.class.resource_options[:xml] || {}
        options = {} if options == true
        options = { :only => options } if options.is_a?(Array)
        options[:only] ||= self.class.resource_options[:only_fields]
        options[:except] ||= self.class.resource_options[:except_fields]
        options = {} unless options.is_a?(Hash)
        render :xml => model.to_xml(options), :location => model.is_a?(Array) ? nil : {:id => model.id}
      when 'destroy'
        head :ok
      end
    end

    def render_xml_api_on_error(action, model, page, pager)
      return if !self.class.resource_options[:xml] || self.class.resource_options[:xml_errors] == false
      case action
      when 'update', 'create', 'destroy'
        render :xml => model.errors
      end
    end

    #
    # HTML
    #
    def render_html_api_on_ok(action, model, page, pager)
      return unless self.class.resource_options[:html]
      return if (options = self.class.resource_options["html_#{action}".to_sym]) == false
      return unless File.exists?(path = "#{File.dirname(__FILE__)}/../../views/html/#{action}.rhtml")
      options = nil if options == true
      options ||= self.class.resource_options[:html] || {}
      options = {} if options == true
      options = { :only => options } if options.is_a?(Array)
      options[:only] ||= self.class.resource_options[:only_fields]
      options[:except] ||= self.class.resource_options[:except_fields]
      options[:filters] ||= self.class.resource_options[:filters]
      options = { :only => options } if options.is_a?(Array)
      render :file => path, :use_full_path => false, :layout => true,
        :locals => {
          :model => model, :options => options || {},
          :page => page, :pager => pager
        }
    end

    def render_html_api_on_error(action, model, page, pager)
      render_html_api_on_ok('edit', model, page, pager) if action == 'update'
      render_html_api_on_ok('new', model, page, pager) if action == 'create'
    end

    #
    # Excel
    #
    def render_xls_api_on_ok(action, model, page, pager)
      return unless self.class.resource_options[:xls]
      return if (options = self.class.resource_options["xls_#{action}".to_sym]) == false
      return unless File.exists?(path = "#{File.dirname(__FILE__)}/../../views/xls/#{action}.rhtml")
      options = nil if options == true
      options ||= self.class.resource_options[:xls] || {}
      options = {} if options == true
      options = { :only => options } if options.is_a?(Array)
      options[:only] ||= self.class.resource_options[:only_fields]
      options[:except] ||= self.class.resource_options[:except_fields]
      options = { :only => options } if options.is_a?(Array)
      render :file => path, :use_full_path => false, :layout => false,
        :locals => {
          :model => model, :options => options || {},
          :page => page, :pager => pager
        }
    end

    #
    # RSS
    #
    def render_rss_api_on_ok(action, model, page, pager)
    end
  end
end