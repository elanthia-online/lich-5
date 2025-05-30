# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Handles UI component creation and styling for the Lich GUI
      module Components
        # Creates a standard button with consistent styling
        #
        # @param label [String, nil] Button label text
        # @param css_provider [Gtk::CssProvider, nil] CSS provider for styling
        # @return [Gtk::Button] Configured button
        def self.create_button(label: nil, css_provider: nil)
          button = label ? Gtk::Button.new(label: label) : Gtk::Button.new
          button.style_context.add_provider(css_provider, Gtk::StyleProvider::PRIORITY_USER) if css_provider
          button
        end

        # Creates a horizontal box with buttons
        #
        # @param buttons [Array<Gtk::Button>] Buttons to include
        # @param expand [Boolean] Whether buttons should expand
        # @param fill [Boolean] Whether buttons should fill space
        # @param padding [Integer] Padding between buttons
        # @return [Gtk::Box] Box containing buttons
        def self.create_button_box(buttons, expand: false, fill: false, padding: 5)
          box = Gtk::Box.new(:horizontal)

          buttons.each do |button|
            box.pack_end(button, expand: expand, fill: fill, padding: padding)
          end

          box
        end

        # Creates a labeled entry field
        #
        # @param label_text [String] Label text
        # @param entry_width [Integer] Width of entry field in characters
        # @param password [Boolean] Whether to hide input as password
        # @return [Hash] Hash containing :label, :entry, and :box components
        def self.create_labeled_entry(label_text, entry_width: 15, password: false)
          label = Gtk::Label.new(label_text)
          label.set_width_chars(entry_width)

          entry = Gtk::Entry.new
          entry.visibility = !password if password

          pane = Gtk::Paned.new(:horizontal)
          pane.add1(label)
          pane.add2(entry)

          { label: label, entry: entry, box: pane }
        end

        # Creates a notebook with tabs
        #
        # @param pages [Array<Hash>] Array of hashes with :widget and :label keys
        # @param tab_position [Symbol] Position of tabs (:left, :right, :top, :bottom)
        # @param show_border [Boolean] Whether to show notebook border
        # @param css_provider [Gtk::CssProvider, nil] CSS provider for styling
        # @return [Gtk::Notebook] Configured notebook
        def self.create_notebook(pages, tab_position: :top, show_border: true, css_provider: nil)
          notebook = Gtk::Notebook.new
          notebook.set_tab_pos(tab_position)
          notebook.show_border = show_border

          if css_provider
            notebook.style_context.add_provider(css_provider, Gtk::StyleProvider::PRIORITY_USER)
          end

          pages.each do |page|
            notebook.append_page(page[:widget], Gtk::Label.new(page[:label]))
          end

          notebook
        end
      end
    end
  end
end
