module ActionExtensions 
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def permalinked_with(param)
      record = class << self; self; end
      record.send :define_method, :find_by_param, lambda {|*args| record.send "find_by_#{param}", args}
      record.send :define_method, :to_param, lambda{ param.to_s}  
    end
  end
end

module ActiveRecord
  class Base
    include ActionExtensions
  end
end
