# Copyright (c) 2010-2016 Michael Dvorkin and contributors
#
# Awesome Print is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
module AwesomePrint
  module ActiveRecord

    def self.included(base)
      base.send :alias_method, :cast_without_active_record, :cast
      base.send :alias_method, :cast, :cast_with_active_record
    end

    # Add ActiveRecord class names to the dispatcher pipeline.
    #------------------------------------------------------------------------------
    def cast_with_active_record(object, type)
      cast = cast_without_active_record(object, type)
      return cast if !defined?(::ActiveRecord::Base)

      if object.is_a?(::ActiveRecord::Base)
        cast = :active_record_instance
      elsif object.is_a?(::ActiveModel::Errors)
        cast = :active_model_error
      elsif object.is_a?(Class) && object.ancestors.include?(::ActiveRecord::Base)
        cast = :active_record_class
      elsif type == :activerecord_relation || object.class.ancestors.include?(::ActiveRecord::Relation)
        cast = :array
      end
      cast
    end

    private

    # Format ActiveRecord instance object.
    #
    # NOTE: by default only instance attributes (i.e. columns) are shown. To format
    # ActiveRecord instance as regular object showing its instance variables and
    # accessors use :raw => true option:
    #
    # ap record, :raw => true
    #
    #------------------------------------------------------------------------------
    def awesome_active_record_instance(object)
      return object.inspect if !defined?(::ActiveSupport::OrderedHash)
      return awesome_object(object) if @options[:raw]

      data = if object.class.column_names != object.attributes.keys
               object.attributes
             else
               object.class.column_names.inject(::ActiveSupport::OrderedHash.new) do |hash, name|
                 if object.has_attribute?(name) || object.new_record?
                   value = object.respond_to?(name) ? object.send(name) : object.read_attribute(name)
                   hash[name.to_sym] = value
                 end
                 hash
               end
             end
      "#{object} #{awesome_hash(data)}"
    end

    # Format ActiveRecord class object.
    #------------------------------------------------------------------------------
    def awesome_active_record_class(object)
      return object.inspect if !defined?(::ActiveSupport::OrderedHash) || !object.respond_to?(:columns) || object.to_s == 'ActiveRecord::Base'
      return awesome_class(object) if object.respond_to?(:abstract_class?) && object.abstract_class?

      data = object.columns.inject(::ActiveSupport::OrderedHash.new) do |hash, c|
        hash[c.name.to_sym] = c.type
        hash
      end

      name = "class #{awesome_simple(object.to_s, :class)}"
      base = "< #{awesome_simple(object.superclass.to_s, :class)}"

      [name, base, awesome_hash(data)].join(' ')
    end

    # Format ActiveModel error object.
    #------------------------------------------------------------------------------
    def awesome_active_model_error(object)
      return object.inspect if !defined?(::ActiveSupport::OrderedHash)
      return awesome_object(object) if @options[:raw]

      data = object.instance_variable_get('@base')
                   .attributes
                   .merge(details: object.details.to_h,
                          messages: object.messages.to_h.transform_values(&:to_a))

      [object.to_s, awesome_hash(data)].join(' ')
    end
  end
end

AwesomePrint::Formatter.send(:include, AwesomePrint::ActiveRecord)
