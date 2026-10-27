# frozen_string_literal: true

require_relative 'sensitive_value'

module Lich
  module WebUI
    # Pure value operations shared by components, forms and the runtime.
    module ValueHelpers
      module_function

      # Copies editable containers and strings, retaining keys and other leaves.
      # Contract.deep_dup separately preserves every scalar's identity.
      # @param value [Object] setting or component value to isolate from edits
      # @return [Object] copied hashes/arrays/strings, or the original other leaf
      def deep_copy(value)
        case value
        when Hash then value.to_h { |key, item| [key, deep_copy(item)] }
        when Array then value.map { |item| deep_copy(item) }
        when String then value.dup
        else value
        end
      end

      # Classifies a value without deciding property scope or permitting reads.
      # @param component [#type, #props] component or adapter shadow node
      # @return [Boolean] password input or an explicitly sensitive component
      def sensitive_value?(component)
        component.type == :password_input || component.props[:sensitive] == true
      end

      # Copies a component's properties with a sensitive input's value redacted, for
      # inspection output only. Wire serialization omits the value instead.
      # @param component [#type, #props] component or builder draft
      # @return [Hash] properties, with :value replaced by the redaction marker when sensitive
      def redacted_props(component)
        return component.props unless sensitive_value?(component) && component.props.key?(:value)

        component.props.merge(value: SensitiveValue::REDACTION)
      end

      # Unwraps an explicit viewer or callback context without coercion/defaulting.
      # @param viewer [Object] viewer identity or object exposing viewer_id
      # @return [Object] unwrapped identity, including nil or false
      def viewer_id(viewer)
        viewer.respond_to?(:viewer_id) ? viewer.viewer_id : viewer
      end

      # Matches the browser's textarea representation without mutating the input.
      # Callers retain their own nontext guards and invalid-value errors.
      # @param value [String] text whose line breaks should be normalized
      # @return [String] text with CRLF and bare CR replaced by LF
      def normalize_text_line_breaks(value)
        value.gsub(/\r\n?/, "\n")
      end
    end
  end
end
