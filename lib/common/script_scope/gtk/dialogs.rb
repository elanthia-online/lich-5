# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # sbounty and sellunder need informational OK dialogs. Their corrected
        # response handlers use the core future; no nested GTK loop or callback
        # thread is introduced. Parent destruction cancels the outstanding modal.
        class MessageDialog < Widget
          # Accepts only same-session parented informational/error dialogs with an OK response.
          # @param parent [Window] owning window
          # @param flags [Array<Symbol>, Symbol] modal/destroy_with_parent compatibility flags
          # @param type [Symbol] :info or :error
          # @param buttons [Symbol] :ok only
          # @param message [Object] content converted to plain text
          # @raise [UnsupportedOperation] for unsupported dialog forms
          def initialize(parent:, flags:, type:, buttons:, message:)
            super()
            valid_flags = Array(flags) - %i[modal destroy_with_parent]
            session.refuse(self, :new) unless parent.is_a?(Window) && parent.session.equal?(session)
            session.refuse(self, :new) unless valid_flags.empty? && %i[info error].include?(type) && buttons == :ok
            @message = String(message)
            @title = type == :error ? 'Error' : 'Information'
            @dialog_parent = parent
            parent.own_dialog(self)
          end

          # Registers the sole supported response handler; execution uses the existing core future.
          # @return [Integer] compatibility signal ID
          # @raise [UnsupportedOperation] unless a response block is supplied
          def signal_connect(name, &block)
            session.refuse(self, "signal:#{name}") unless name.to_s == 'response' && block
            @response = block
            1
          end

          # Retains an informational prompt while its parent's first viewer attaches.
          # Parent destruction and owner termination cancel the existing future;
          # this adds neither a nested event loop nor credential-dialog support.
          # @return [MessageDialog] this dialog
          def show_all
            return self if @future || destroyed?

            @future = session.port.modal(title: @title, body: @message,
                                         buttons: [{ id: 'ok', label: 'OK' }], no_viewer: :wait)
            @future.then do |result|
              session.synchronize { @response&.call(self, :ok) if result.button == 'ok' && !destroyed? }
            ensure
              destroy
            end
            self
          end
          alias show show_all

          # Waits for the core modal completion outside an owner callback.
          # @return [Symbol] :ok for acceptance, otherwise :cancel
          # @raise [UnsupportedOperation] when called inside a viewer callback
          def run
            session.refuse(self, :run) if session.in_callback?
            show_all
            @future&.await&.button == 'ok' ? :ok : :cancel
          end

          # Cancels the outstanding future and releases parent ownership once.
          # @return [MessageDialog] self, including repeated destruction
          def destroy
            return self if destroyed?

            mark_destroyed
            @dialog_parent.forget_dialog(self)
            @future&.cancel(reason: :owner)
            self
          end
        end

        # Both accepted separator consumers request horizontal section breaks.
        class Separator < Widget
          # Accepts the observed horizontal divider orientation only.
          # @param orientation [Symbol] :horizontal
          # @raise [UnsupportedOperation] for other orientations
          def initialize(orientation)
            super()
            session.refuse(self, :new) unless orientation == :horizontal
          end

          protected

          def component_type = :divider
        end

        class HSeparator < Separator
          # Constructs the horizontal separator compatibility spelling.
          def initialize
            super(:horizontal)
          end
        end
      end
    end
  end
end
