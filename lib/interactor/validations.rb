# frozen_string_literal: true

module Interactor
  # Internal: Methods for validating required context attributes.
  module Validations
    # Internal: Install validation behavior in the given class.
    def self.included(base)
      base.class_eval do
        extend ClassMethods

        # Ensure validation hook is configured in subclasses
        def self.inherited(subclass)
          super

          subclass.class_eval do
            before_hooks.unshift(:validate_required_attributes) unless before_hooks.include?(:validate_required_attributes)
          end
        end
      end
    end

    # Internal: Validation class methods.
    module ClassMethods
      # Public: Declare required context attributes. These attributes must be
      # present (not nil) when the interactor is invoked, otherwise the
      # context will fail with an ArgumentError.
      #
      # attributes - Zero or more Symbol attribute names that are required in
      #              the context.
      #
      # Examples
      #
      #   class AuthenticateUser
      #     include Interactor
      #
      #     requires :email, :password
      #
      #     def call
      #       # email and password are guaranteed to be present
      #       user = User.authenticate(context.email, context.password)
      #       context.user = user if user
      #     end
      #   end
      #
      #   AuthenticateUser.call(email: "test@example.com", password: "secret")
      #   # => #<Interactor::Context email="test@example.com" password="secret">
      #
      #   AuthenticateUser.call(email: "test@example.com")
      #   # => ArgumentError: Required attribute password is missing
      #
      # Returns nothing.
      def requires(*attributes)
        @required_attributes ||= []
        @required_attributes.concat(attributes.map(&:to_sym))
        @required_attributes.uniq!

        # Delegate required attributes to context for convenience
        attributes.each do |attr|
          define_method(attr) do
            context.public_send(attr)
          end
        end
      end

      # Internal: An Array of required attribute names.
      #
      # Returns an Array of Symbol attribute names or an empty Array.
      def required_attributes
        @required_attributes ||= []
      end
    end

    # Internal: Validate required attributes before interactor invocation.
    #
    # Returns nothing.
    # Raises ArgumentError if any required attributes are missing.
    def validate_required_attributes
      missing = self.class.required_attributes.select do |attr|
        value = context.public_send(attr)
        value.nil?
      end

      return if missing.empty?

      # Raise ArgumentError for the first missing attribute to match expected behavior
      missing_attr = missing.first
      raise ArgumentError, "Required attribute #{missing_attr} is missing"
    end
  end
end
