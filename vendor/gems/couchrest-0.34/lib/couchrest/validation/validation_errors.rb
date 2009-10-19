# Extracted from dm-validations 0.9.10
#
# Copyright (c) 2007 Guy van den Berg
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module CouchRest
  module Validation

    ##
    #
    # @author Guy van den Berg
    # @since  0.9
    class ValidationErrors

      include Enumerable

      @@default_error_messages = {
        :absent => '%s must be absent',
        :inclusion => '%s must be one of [%s]',
        :invalid => '%s has an invalid format',
        :confirmation => '%s does not match the confirmation',
        :accepted  => "%s is not accepted",
        :nil => '%s must not be nil',
        :blank => '%s must not be blank',
        :length_between => '%s must be between %s and %s characters long',
        :too_long => '%s must be less than %s characters long',
        :too_short => '%s must be more than %s characters long',
        :wrong_length => '%s must be %s characters long',
        :taken => '%s is already taken',
        :not_a_number => '%s must be a number',
        :not_an_integer => '%s must be an integer',
        :greater_than => '%s must be greater than %s',
        :greater_than_or_equal_to => "%s must be greater than or equal to %s",
        :equal_to => "%s must be equal to %s",
        :less_than => '%s must be less than %s',
        :less_than_or_equal_to => "%s must be less than or equal to %s",
        :value_between => '%s must be between %s and %s',
        :primitive => '%s must be of type %s'
      }

      # Holds a hash with all the default error messages that can be replaced by your own copy or localizations.
      cattr_writer :default_error_messages

      def self.default_error_message(key, field, *values)
        field = CouchRest.humanize(field)
        @@default_error_messages[key] % [field, *values].flatten
      end

      # Clear existing validation errors.
      def clear!
        errors.clear
      end

      # Add a validation error. Use the field_name :general if the errors does
      # not apply to a specific field of the Resource.
      #
      # @param <Symbol> field_name the name of the field that caused the error
      # @param <String> message    the message to add
      def add(field_name, message)
        (errors[field_name.to_sym] ||= []) << message
      end

      # Collect all errors into a single list.
      def full_messages
        errors.inject([]) do |list, pair|
          list += pair.last
        end
      end

      # Return validation errors for a particular field_name.
      #
      # @param <Symbol> field_name the name of the field you want an error for
      def on(field_name)
        errors_for_field = errors[field_name.to_sym]
        errors_for_field.blank? ? nil : errors_for_field
      end

      def each
        errors.map.each do |k, v|
          next if v.blank?
          yield(v)
        end
      end

      def empty?
        entries.empty?
      end

      # Return size of errors hash
      #
      # Allows us to play nicely with Rails' helpers
      def count
        errors.size
      end

      def method_missing(meth, *args, &block)
        errors.send(meth, *args, &block)
      end

      private
      def errors
        @errors ||= {}
      end

    end # class ValidationErrors
  end # module Validation
end # module CouchRest
