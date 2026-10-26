# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      private

      # Validates exactly the server-declared terminal scope before retaining submitted values.
      # Secrets become disposable carriers; mutable raw secret strings are scrubbed in ensure.
      # @param attachment [ViewerStore::Attachment] exact admitted viewer/page association
      # @param terminal [Component] terminal control declaring the submission scope
      # @param message [Hash] validated protocol envelope
      # @return [Submission, nil] terminal snapshot, or nil for a nonterminal event
      # @raise [Protocol::Refusal] for a mismatched or unauthorized submission scope
      # @api private
      def build_submission(attachment, terminal, message)
        raw_values = message.fetch(:submission, [])
        event_schema = Contract.schema(terminal.type)[:events].fetch(message[:event].to_sym)
        unless event_schema[:terminal]
          raise Protocol::Refusal.new(:submission_scope, 'submission requires a terminal event') unless raw_values.empty?

          return nil
        end
        scope = attachment.render.submissions.fetch(terminal.cid, [])
        unless raw_values.length == scope.length
          raise Protocol::Refusal.new(:submission_scope, 'submission value count does not match server scope')
        end

        components = scope.map { |cid| find_component!(attachment, cid) }
        validated = components.each_with_index.map do |component, index|
          value = @validator.validate_input_value!(
            component.type, raw_values[index], props: component.props,
            owner: owner_label(attachment.page.owner), page_id: attachment.page.id, cid: component.cid
          )
          if %i[text_input textarea].include?(component.type) && component.props[:read_only]
            # The browser may still display an older server value. Validate
            # against its delivery, but retain the latest server-owned value.
            value = @viewers.read_only_submission(attachment, component, value)
          end
          [component, value]
        end
        selected_groups = validated.filter_map do |component, value|
          component.props[:group] if component.type == :radio_option && value
        end
        unless selected_groups.uniq.length == selected_groups.length
          raise Protocol::Refusal.new(:submission_scope, 'radio group has multiple selected options')
        end
        # Capture all differences before applying any values: selecting a radio
        # option also updates its peers. Native callbacks still receive only the
        # terminal event; the imperative adapter uses this metadata to reconcile
        # legacy change handlers when Save overtakes a stale change-event retry.
        input_changes = validated.filter_map do |component, value|
          next if sensitive?(component)

          previous = @viewers.input_value(attachment, component)
          # textarea.value normalizes CRLF and lone CR to LF. Compare that
          # representation only; preserve the validated snapshot value below.
          changed = if component.type == :textarea
                      ValueHelpers.normalize_text_line_breaks(previous) != ValueHelpers.normalize_text_line_breaks(value)
                    else
                      previous != value
                    end
          component if changed
        end
        values = validated.to_h do |component, value|
          if sensitive?(component)
            [component.cid, SensitiveValue.viewer(value)]
          else
            @viewers.set_input(attachment, component, value) unless %i[text_input textarea].include?(component.type) && component.props[:read_only]
            [component.cid, value]
          end
        end
        Submission.new(viewer_id: attachment.viewer_id, values: values, input_changes: input_changes)
      ensure
        scrub_sensitive_raw!(components, raw_values) if defined?(components) && components
      end

      # Overwrites mutable raw strings at known sensitive positions after snapshot construction.
      # @param components [Array<Component>] inputs in the server-declared submission order
      # @param raw_values [Array<Object>] submitted raw values in the same order
      # @return [void]
      # @api private
      def scrub_sensitive_raw!(components, raw_values)
        components.each_with_index do |component, index|
          next unless sensitive?(component)
          next unless raw_values[index].is_a?(String) && !raw_values[index].frozen?

          raw_values[index].replace("\0" * raw_values[index].bytesize)
          raw_values[index].clear
        end
      end

      # Requests clearing only the secret controls present in this submission.
      # @param connection [Object] authenticated viewer transport
      # @param snapshot [Submission, nil] accepted terminal snapshot with optional secret carriers
      # @return [void]
      # @api private
      def clear_sensitive_client(connection, snapshot)
        sensitive_cids = snapshot&.sensitive_cids || []
        return if sensitive_cids.empty?

        connection.send_text(JSON.generate(type: 'clear_sensitive', cids: sensitive_cids))
      end
    end
  end
end
