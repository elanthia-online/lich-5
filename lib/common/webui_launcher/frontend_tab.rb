# frozen_string_literal: true

require_relative '../../webui'
require_relative '../frontend_editor'

module Lich
  module Common
    class WebUILauncher
      # Native frontend editor. Presentation and validation are adapted from
      # Nisugi's PR #1652; persistence and discovery run on the launcher worker.
      # The render path consumes cached data and never performs discovery or IO.
      class FrontendTab
        CAPABILITIES_PER_ROW = 3

        # Builds cached editor state and accepts the launcher's close/write gate.
        # @param data_dir [String] settings directory
        # @param locator [Object] frontend discovery collaborator
        # @param executor [Object] serialized background worker
        # @param on_change [Proc] request a presentation refresh
        # @param on_catalog_change [Proc] reload parent frontend choices
        # @param commit [Proc] run a write only while the parent remains open
        def initialize(data_dir:, locator:, executor:, on_change:, on_catalog_change: proc {}, commit: ->(&work) { work.call })
          @data_dir = data_dir
          @frontend_locator = locator
          @executor = executor
          @on_change = on_change
          @on_catalog_change = on_catalog_change
          @commit = commit
          @mutex = Mutex.new
          @closed = false
          @busy = false
          @state = { frontend_creating: false, frontend_error: nil, frontend_revision: 0 }
          load_snapshot
        end

        # Closing cancels queued work. An atomic save already begun may finish,
        # but its completion cannot refresh a closed launcher.
        # @return [Boolean] true after setting the editor closed flag
        def close
          @mutex.synchronize { @closed = true }
        end

        require_relative 'frontend_tab/presentation'

        # Selection is resolved against the server's cached catalog, never a
        # browser-provided record or a filesystem lookup on the event thread.
        # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
        # @return [void] requests refresh only for an accepted cached selection
        def select_frontend(event)
          id = event.payload.fetch(:rows).first
          update_draft do
            draft = @fields[id]
            return unless draft

            @state.merge!(frontend_creating: false, frontend_error: nil,
                          frontend_draft: draft.dup)
          end
        end

        # Starts an unsaved custom-frontend draft if the controller accepts edits.
        # @return [void]
        def begin_new_frontend
          update_draft do
            @state.merge!(frontend_creating: true, frontend_error: nil, frontend_draft: {
              id: '', label: '', built_in: false, command: '', detected_command: '',
              directory: '', arguments: '', capabilities: []
            })
          end
        end

        # A submitted disabled input is still untrusted. Existing identity is
        # pinned to the selected server record; only a new record supplies an id.
        # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
        # @return [void] queues the existing editor mutation workflow
        def save_frontend(event)
          fields = frontend_fields_from(event)
          queue_edit do |snapshot|
            creating = snapshot[:frontend_creating]
            unless creating || fields[:id] == snapshot.fetch(:frontend_draft).fetch(:id)
              raise ArgumentError, 'Frontend selection changed. Select it again before saving.'
            end
            FrontendSettings.load!(data_dir: @data_dir)
            builtins, custom, id = FrontendEditor.apply(FrontendSettings.current, fields, creating: creating)
            FrontendSettings.replace!(data_dir: @data_dir, builtins: builtins, custom: custom)
            load_snapshot(selected: id)
          end
        end

        # Queues deletion through FrontendEditor, which refuses built-in removal.
        # Reloads settings before writing and refreshes the snapshot afterward.
        # @return [void]
        def delete_frontend
          queue_edit do |snapshot|
            id = snapshot.fetch(:frontend_draft).fetch(:id)
            FrontendSettings.load!(data_dir: @data_dir)
            builtins, custom = FrontendEditor.remove(FrontendSettings.current, id)
            FrontendSettings.replace!(data_dir: @data_dir, builtins: builtins, custom: custom)
            load_snapshot
          end
        end

        # Queues a settings/discovery reload while attempting to retain the selected frontend.
        # @return [void]
        def reload_frontends
          queue_edit do |snapshot|
            FrontendSettings.load!(data_dir: @data_dir)
            load_snapshot(selected: snapshot[:frontend_draft]&.fetch(:id))
          end
        end

        private

        # Applies a draft change only while open and idle, then notifies outside the lock.
        # @return [void]
        # @api private
        def update_draft
          accepted = @mutex.synchronize do
            next false if @closed || @busy
            yield
            @state[:frontend_revision] += 1
            true
          end
          @on_change.call if accepted
        end

        # Serialize mutations with the rest of the launcher. The short lock
        # admits or cancels work; no IO occurs while holding the UI state lock.
        # The parent commit gate serializes persistence with launcher closure.
        # @api private
        # @yieldparam snapshot [Hash] editor state accepted for this operation
        # @return [void]
        def queue_edit
          snapshot = @mutex.synchronize do
            next if @closed || @busy
            @busy = true
            @state.dup
          end
          return unless snapshot

          @executor.post do
            begin
              @commit.call do
                next if @mutex.synchronize { @closed }

                yield snapshot
                @on_catalog_change.call
              end
            rescue StandardError => error
              @mutex.synchronize { @state[:frontend_error] = error.message }
            ensure
              @mutex.synchronize { @busy = false }
              @on_change.call unless @mutex.synchronize { @closed }
            end
          end
        end

        # Refreshes discovery and rebuilds editor fields before publishing a locked snapshot.
        # @param selected [String, nil] preferred frontend ID
        # @return [void]
        # @api private
        def load_snapshot(selected: nil)
          @frontend_locator.refresh! if @frontend_locator.respond_to?(:refresh!)
          rows = FrontendEditor.rows(locator: @frontend_locator)
          fields = rows.to_h { |row| [row[:id], FrontendEditor.editor_fields(row[:id], locator: @frontend_locator)] }
          @mutex.synchronize do
            @fields = fields
            @state[:frontend_revision] += 1
            @state.merge!(frontends: rows, frontend_creating: false, frontend_error: nil,
                          frontend_draft: fields[selected] || fields.values.first)
          end
        end

        # Allows deletion only for a persisted custom frontend, never a new draft or built-in.
        # @param state [Hash] captured credential-free presentation state
        # @return [Boolean, nil]
        # @api private
        def frontend_deletable?(state)
          draft = state[:frontend_draft]
          draft && !state[:frontend_creating] && !draft[:built_in] && !draft[:id].empty?
        end

        # Extracts the explicitly submitted editor fields and allowlisted capability checkboxes.
        # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
        # @return [Hash] frontend field values
        # @api private
        def frontend_fields_from(event)
          submission = event.submission
          values = submission.cids.to_h { |cid| [cid, submission.fetch(cid)] }
          field = ->(suffix) { values.find { |cid, _| cid.end_with?(suffix) }&.last }
          fields = %i[id label command directory arguments].to_h do |name|
            [name, field.call("text_input:frontend-#{name}").to_s]
          end
          fields[:capabilities] = Frontend.capability_vocabulary.filter_map do |capability|
            capability.to_s if field.call("checkbox:frontend-capability-#{capability}") == true
          end
          fields
        end
      end
    end
  end
end
