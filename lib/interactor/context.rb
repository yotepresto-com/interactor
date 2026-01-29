module Interactor
  # Public: The object for tracking state of an Interactor's invocation. The
  # context is used to initialize the interactor with the information required
  # for invocation. The interactor manipulates the context to produce the result
  # of invocation.
  #
  # The context is the mechanism by which success and failure are determined and
  # the context is responsible for tracking individual interactor invocations
  # for the purpose of rollback.
  #
  # The context may be manipulated using arbitrary getter and setter methods.
  #
  # Examples
  #
  #   context = Interactor::Context.new
  #   # => #<Interactor::Context>
  #   context.foo = "bar"
  #   # => "bar"
  #   context
  #   # => #<Interactor::Context foo="bar">
  #   context.hello = "world"
  #   # => "world"
  #   context
  #   # => #<Interactor::Context foo="bar" hello="world">
  #   context.foo = "baz"
  #   # => "baz"
  #   context
  #   # => #<Interactor::Context foo="baz" hello="world">
  class Context
    # Internal: Initialize a new Context with optional hash of attributes.
    #
    # hash - A Hash whose key/value pairs are used to initialize the context.
    #        (default: {})
    def initialize(hash = {})
      @table = {}
      hash.each { |key, value| self[key.to_sym] = value }
    end

    # Internal: Initialize an Interactor::Context or preserve an existing one.
    # If the argument given is an Interactor::Context, the argument is returned.
    # Otherwise, a new Interactor::Context is initialized from the provided
    # hash.
    #
    # The "build" method is used during interactor initialization.
    #
    # context - A Hash whose key/value pairs are used in initializing a new
    #           Interactor::Context object. If an existing Interactor::Context
    #           is given, it is simply returned. (default: {})
    #
    # Examples
    #
    #   context = Interactor::Context.build(foo: "bar")
    #   # => #<Interactor::Context foo="bar">
    #   context.object_id
    #   # => 2170969340
    #   context = Interactor::Context.build(context)
    #   # => #<Interactor::Context foo="bar">
    #   context.object_id
    #   # => 2170969340
    #
    # Returns the Interactor::Context.
    def self.build(context = {})
      if self === context
        context
      else
        new(context)
      end
    end

    # Internal: Access attributes using bracket notation.
    #
    # key - A Symbol or String key to access.
    #
    # Returns the value for the given key, or nil if not set.
    def [](key)
      @table[key.to_sym]
    end

    # Internal: Set attributes using bracket notation.
    #
    # key - A Symbol or String key to set.
    # value - The value to assign.
    #
    # Returns the assigned value.
    def []=(key, value)
      @table[key.to_sym] = value
    end

    # Public: Convert the context to a hash.
    #
    # Returns a Hash containing all context attributes.
    def to_h
      @table.dup
    end

    # Internal: Handle dynamic method calls for getters and setters.
    #
    # method - The method name as a Symbol.
    # *args - Arguments passed to the method.
    #
    # Returns the value for getters, or the assigned value for setters.
    def method_missing(method, *args)
      method_name = method.to_s

      if method_name.end_with?("=")
        # Setter method
        key = method_name[0..-2].to_sym
        @table[key] = args.first
      else
        # Getter method
        @table[method]
      end
    end

    # Internal: Check if a method is defined or can be handled dynamically.
    #
    # method - The method name as a Symbol.
    # include_private - Whether to include private methods (default: false).
    #
    # Returns true if the method can be handled dynamically, false otherwise.
    def respond_to_missing?(method, include_private = false)
      # All undefined methods can be handled dynamically (getters and setters)
      true
    end

    # Public: Whether the Interactor::Context is successful. By default, a new
    # context is successful and only changes when explicitly failed.
    #
    # The "success?" method is the inverse of the "failure?" method.
    #
    # Examples
    #
    #   context = Interactor::Context.new
    #   # => #<Interactor::Context>
    #   context.success?
    #   # => true
    #   context.fail!
    #   # => Interactor::Failure: #<Interactor::Context>
    #   context.success?
    #   # => false
    #
    # Returns true by default or false if failed.
    def success?
      !failure?
    end

    # Public: Whether the Interactor::Context has failed. By default, a new
    # context is successful and only changes when explicitly failed.
    #
    # The "failure?" method is the inverse of the "success?" method.
    #
    # Examples
    #
    #   context = Interactor::Context.new
    #   # => #<Interactor::Context>
    #   context.failure?
    #   # => false
    #   context.fail!
    #   # => Interactor::Failure: #<Interactor::Context>
    #   context.failure?
    #   # => true
    #
    # Returns false by default or true if failed.
    def failure?
      @failure || false
    end

    # Public: Fail the Interactor::Context. Failing a context raises an error
    # that may be rescued by the calling interactor. The context is also flagged
    # as having failed.
    #
    # Optionally the caller may provide a hash of key/value pairs to be merged
    # into the context before failure.
    #
    # context - A Hash whose key/value pairs are merged into the existing
    #           Interactor::Context instance. (default: {})
    #
    # Examples
    #
    #   context = Interactor::Context.new
    #   # => #<Interactor::Context>
    #   context.fail!
    #   # => Interactor::Failure: #<Interactor::Context>
    #   context.fail! rescue false
    #   # => false
    #   context.fail!(foo: "baz")
    #   # => Interactor::Failure: #<Interactor::Context foo="baz">
    #
    # Raises Interactor::Failure initialized with the Interactor::Context.
    def fail!(context = {})
      context.each { |key, value| self[key.to_sym] = value }
      @failure = true
      raise Failure, self
    end

    # Internal: Track that an Interactor has been called. The "called!" method
    # is used by the interactor being invoked with this context. After an
    # interactor is successfully called, the interactor instance is tracked in
    # the context for the purpose of potential future rollback.
    #
    # interactor - An Interactor instance that has been successfully called.
    #
    # Returns nothing.
    def called!(interactor)
      _called << interactor
    end

    # Public: Roll back the Interactor::Context. Any interactors to which this
    # context has been passed and which have been successfully called are asked
    # to roll themselves back by invoking their "rollback" instance methods.
    #
    # Examples
    #
    #   context = MyInteractor.call(foo: "bar")
    #   # => #<Interactor::Context foo="baz">
    #   context.rollback!
    #   # => true
    #   context
    #   # => #<Interactor::Context foo="bar">
    #
    # Returns true if rolled back successfully or false if already rolled back.
    def rollback!
      return false if @rolled_back
      _called.reverse_each(&:rollback)
      @rolled_back = true
    end

    # Internal: An Array of successfully called Interactor instances invoked
    # against this Interactor::Context instance.
    #
    # Examples
    #
    #   context = Interactor::Context.new
    #   # => #<Interactor::Context>
    #   context._called
    #   # => []
    #
    #   context = MyInteractor.call(foo: "bar")
    #   # => #<Interactor::Context foo="baz">
    #   context._called
    #   # => [#<MyInteractor @context=#<Interactor::Context foo="baz">>]
    #
    # Returns an Array of Interactor instances or an empty Array.
    def _called
      @called ||= []
    end

    # Internal: Support for ruby 3.0 pattern matching
    #
    # Examples
    #
    #   context = MyInteractor.call(foo: "bar")
    #
    #   # => #<Interactor::Context foo="bar">
    #   context => { foo: }
    #   foo == "bar"
    #   # => true
    #
    #
    #   case context
    #   in success: true, result: { first:, second: }
    #     do_stuff(first, second)
    #   in failure: true, error_message:
    #     log_error(message: error_message)
    #   end
    #
    # Returns the context as a hash, including success and failure
    def deconstruct_keys(keys)
      to_h.merge(
        success: success?,
        failure: failure?
      )
    end

    # Internal: Access the internal table (for compatibility with tests).
    #
    # Returns the internal hash table.
    attr_reader :table
    private :table
  end
end
