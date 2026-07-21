#==============================================================================
# Kanto Reloaded Hooks
#==============================================================================
# Shared, idempotent alias wrapper for instance and singleton methods.
#==============================================================================

module KantoReloaded
  module Hooks
    @installations = {}

    class Invocation
      attr_reader :receiver
      attr_reader :method_name
      attr_reader :alias_name
      attr_reader :hook_id

      def initialize(receiver, method_name, alias_name, hook_id, arguments, block)
        @receiver = receiver
        @method_name = method_name
        @alias_name = alias_name
        @hook_id = hook_id
        @arguments = arguments
        @block = block
      end

      def arguments
        @arguments.dup
      end

      def block
        @block
      end

      def block_given?
        !@block.nil?
      end

      def call(*override_arguments, &override_block)
        forwarded_arguments = override_arguments.empty? ? @arguments : override_arguments
        forwarded_block = override_block || @block
        @receiver.__send__(@alias_name, *forwarded_arguments, &forwarded_block)
      end
      alias call_original call

      def call_with(arguments, callable = @block)
        @receiver.__send__(@alias_name, *Array(arguments), &callable)
      end

      def call_without_block(*override_arguments)
        forwarded_arguments = override_arguments.empty? ? @arguments : override_arguments
        @receiver.__send__(@alias_name, *forwarded_arguments)
      end

      ruby2_keywords(:call) if respond_to?(:ruby2_keywords, true)
      ruby2_keywords(:call_original) if respond_to?(:ruby2_keywords, true)
      ruby2_keywords(:call_without_block) if respond_to?(:ruby2_keywords, true)
    end

    class << self
      def wrap(target, method_name, hook_id, options = {}, &wrapper)
        raise ArgumentError, "Hook wrapper block is required" unless wrapper
        data = options.is_a?(Hash) ? options : {}
        owner = method_owner(target, data)
        return missing_method(target, method_name, hook_id, data) unless owner && method_available?(owner, method_name)

        method = method_name.to_sym
        id = normalize_id(hook_id)
        base_alias_name = alias_name_for(method, id)
        already_wrapped = hook_effective?(owner, method, base_alias_name)
        return true if already_wrapped && !data[:reattach]
        alias_name = method_defined_directly?(owner, base_alias_name) ?
          next_reattach_alias(owner, base_alias_name) : base_alias_name
        original_visibility = visibility(owner, method)

        owner.class_eval do
          alias_method alias_name, method
          define_method(method) do |*arguments, &original_block|
            invocation = KantoReloaded::Hooks::Invocation.new(
              self, method, alias_name, id, arguments, original_block
            )
            instance_exec(invocation, *arguments, &wrapper)
          end
          ruby2_keywords(method) if respond_to?(:ruby2_keywords, true)
          send(original_visibility, method)
          send(original_visibility, alias_name)
        end
        remember_installation(owner, method, id, alias_name)
        log_install(target, method, id, data, original_visibility)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Hook install failed for #{target_label(target, options)}##{method_name}",
          e,
          channel: :hooks
        ) if defined?(KantoReloaded::Log)
        false
      end

      def wrapped?(target, method_name, hook_id, options = {})
        owner = method_owner(target, options.is_a?(Hash) ? options : {})
        owner && hook_effective?(owner, method_name, alias_name_for(method_name, hook_id))
      rescue
        false
      end

      def outermost?(target, method_name, hook_id, options = {})
        owner = method_owner(target, options.is_a?(Hash) ? options : {})
        return false unless owner
        installation = @installations[installation_key(owner, method_name, hook_id)]
        return false unless installation
        owner.instance_method(method_name.to_sym) == installation[:wrapper_method]
      rescue
        false
      end

      def alias_name(method_name, hook_id)
        alias_name_for(method_name, hook_id)
      end

      private

      def method_owner(target, options)
        return nil unless target
        data = options.is_a?(Hash) ? options : {}
        return class << target; self; end if data[:singleton]
        target
      end

      def method_available?(owner, method_name)
        owner.public_method_defined?(method_name) ||
          owner.protected_method_defined?(method_name) ||
          owner.private_method_defined?(method_name)
      end

      def method_defined_directly?(owner, method_name)
        method = method_name.to_sym
        owner.public_instance_methods(false).include?(method) ||
          owner.protected_instance_methods(false).include?(method) ||
          owner.private_instance_methods(false).include?(method)
      end

      def hook_effective?(owner, method_name, alias_name)
        return true if method_defined_directly?(owner, alias_name)
        return false unless method_available?(owner, alias_name)
        owner.instance_method(method_name.to_sym).owner != owner
      rescue
        false
      end

      def visibility(owner, method_name)
        return :private if owner.private_method_defined?(method_name)
        return :protected if owner.protected_method_defined?(method_name)
        :public
      end

      def alias_name_for(method_name, hook_id)
        method_token = sanitize(method_name)
        id_token = sanitize(normalize_id(hook_id))
        :"kanto_reloaded_hook_#{id_token}_#{method_token}"
      end

      def next_reattach_alias(owner, base_alias_name)
        generation = 2
        loop do
          candidate = :"#{base_alias_name}_reattach_#{generation}"
          return candidate unless method_defined_directly?(owner, candidate)
          generation += 1
        end
      end

      def remember_installation(owner, method_name, hook_id, alias_name)
        @installations[installation_key(owner, method_name, hook_id)] = {
          :alias_name => alias_name,
          :wrapper_method => owner.instance_method(method_name.to_sym)
        }
      end

      def installation_key(owner, method_name, hook_id)
        [owner.object_id, method_name.to_sym, normalize_id(hook_id)]
      end

      def normalize_id(value)
        text = value.to_s.strip.downcase
        raise ArgumentError, "Hook id is empty" if text.empty?
        text.to_sym
      end

      def sanitize(value)
        value.to_s.gsub(/[^a-zA-Z0-9_]+/, "_").gsub(/\A_+|_+\z/, "").downcase
      end

      def missing_method(target, method_name, hook_id, options)
        return false unless options.is_a?(Hash) && options[:required]
        raise NameError, "Missing hook target #{target_label(target, options)}##{method_name} for #{hook_id}"
      end

      def target_label(target, options)
        suffix = options.is_a?(Hash) && options[:singleton] ? ".singleton" : ""
        "#{target}#{suffix}"
      end

      def log_install(target, method_name, hook_id, options, original_visibility)
        return unless defined?(KantoReloaded::Log)
        message = "Installed hook #{hook_id} on #{target_label(target, options)}##{method_name} (#{original_visibility})"
        if KantoReloaded::Log.respond_to?(:debug_once)
          KantoReloaded::Log.debug_once(message, :hooks, key: "hook:#{target_label(target, options)}:#{method_name}:#{hook_id}")
        else
          KantoReloaded::Log.debug(message, :hooks)
        end
      end
    end
  end
end
