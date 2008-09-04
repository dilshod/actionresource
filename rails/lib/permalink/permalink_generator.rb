require 'cgi'
module ActiveRecord
  module Acts #:nodoc:
    module Permalink #:nodoc:
      class PermalinkGenerationError < StandardError
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_permalinked(options = {})
          #validates_presence_of :permalink
          #validates_uniqueness_of :permalink
          #validates_length_of :permalink, :in => 4..32

          include ActiveRecord::Acts::Permalink::InstanceMethods
          extend ActiveRecord::Acts::Permalink::SingletonMethods
        end
      end

      module InstanceMethods
        def generate_permalink(*options)
          options = options[-1].is_a?(Hash) ? options.pop : {}
          obj = options[:object] || self.class
          value = options[:value] || permalink
          path = options[:path] || '0'
          exclude = options[:exclude] || []
          controller = options[:controller] || ''
          #
          path.chop! if path
          value = value.to_s.downcase.strip.gsub(/[^-_\s[:alnum:]\x80-\xFE]/, '').squeeze(' ').tr(' ', '_').gsub('.', '_')
          value = (value.blank?) ? '_' : value
          #
          def test_permalink(path, controller)
            begin
              c = ::ActionController::Routing::Routes.recognize_path(path, {:method => :get})
            rescue
              return true
            end
            c.nil? or
            c[:controller] == controller.to_s and
            ["show", "edit", "update", "destroy"].include?(c[:action])
          end

          tries = 0
          while tries < 1024 &&
            (
              exclude.include?(value) ||
              !(path.nil? || test_permalink(path + value, controller)) ||
              obj.find(
                :first,
                :conditions => ["permalink = ? and id != ?", value, (self.id || 0)]
              )
            )
            value.next!
            value = value.to_s.downcase.strip.gsub(/[^-_\s[:alnum:]]/, '').squeeze(' ').tr(' ', '_')
            value = (value.blank?) ? '_' : value
            tries += 1
          end
          raise PermalinkGenerationError if tries == 1024
          self.permalink = value #CGI.escape(value)
        end

        #def to_param
        #  permalink
        #end
      end

      module SingletonMethods
        #def find_by_param *args
        #  find_by_permalink(*args)
        #end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Permalink)
