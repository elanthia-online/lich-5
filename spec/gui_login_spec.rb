require 'login_spec_helper'

RSpec.describe Lich::Common, "#gui_login" do
  # Since gui_login is a complex method with UI interactions,
  # we'll focus on testing its integration with other components

  let(:test_instance) { Class.new { include Lich::Common }.new }
  let(:data_dir) { "/tmp/test_data" }
  let(:entry_data) { [] }
  let(:launch_data) { ["KEY=value", "SERVER=game.example.com"] }

  # Create test doubles at RSpec example group scope
  let(:custom_launch_entry) { double("CustomLaunchEntry", visible: nil) }
  let(:custom_launch_dir) { double("CustomLaunchDir", visible: nil) }
  let(:bonded_pair_char) { double("BondedPairChar", visible: nil) }
  let(:bonded_pair_inst) { double("BondedPairInst", visible: nil) }
  let(:slider_box) { double("SliderBox", visible: nil) }
  let(:notebook) { double("Notebook", set_page: nil) }
  let(:tab_widget) { double("TabWidget") }
  let(:window) { double("Window", destroy: nil) }
  let(:account_manager_ui) { double("AccountManagerUI", create_accounts_tab: nil, create_add_character_tab: nil, create_add_account_tab: nil) }
  let(:saved_login_tab) { double("SavedLoginTab", ui_elements: saved_login_ui, tab_widget: tab_widget) }
  let(:manual_login_tab) { double("ManualLoginTab", ui_elements: manual_login_ui, tab_widget: tab_widget, update_theme_state: nil) }
  let(:saved_login_ui) { { bonded_pair_char: bonded_pair_char, bonded_pair_inst: bonded_pair_inst, slider_box: slider_box } }
  let(:manual_login_ui) { { custom_launch_entry: custom_launch_entry, custom_launch_dir: custom_launch_dir } }

  before do
    # Setup test directory
    FileUtils.mkdir_p(data_dir)

    # Remove constants if they exist to ensure clean test environment
    if Lich.const_defined?(:Common) && Lich::Common.const_defined?(:GUI)
      if Lich::Common::GUI.const_defined?(:AccountManagerUI)
        Lich::Common::GUI.send(:remove_const, :AccountManagerUI)
      end
      if Lich::Common::GUI.const_defined?(:SavedLoginTab)
        Lich::Common::GUI.send(:remove_const, :SavedLoginTab)
      end
      if Lich::Common::GUI.const_defined?(:ManualLoginTab)
        Lich::Common::GUI.send(:remove_const, :ManualLoginTab)
      end
    end

    # Mock constants and instance variables
    stub_const("DATA_DIR", data_dir)
    stub_const("LICH_VERSION", "5.0.0")

    # Mock YamlState.load_saved_entries
    allow(Lich::Common::GUI::YamlState).to receive(:load_saved_entries).and_return(entry_data)

    # Mock YamlState.save_entries
    allow(Lich::Common::GUI::YamlState).to receive(:save_entries).and_return(true)

    # Mock Accessibility as a module
    stub_const("Lich::Common::GUI::Accessibility", Module.new)
    allow(Lich::Common::GUI::Accessibility).to receive(:initialize_accessibility)
    allow(Lich::Common::GUI::Accessibility).to receive(:add_keyboard_navigation)
    allow(Lich::Common::GUI::Accessibility).to receive(:make_window_accessible)

    # Mock ConversionUI as a module
    stub_const("Lich::Common::GUI::ConversionUI", Module.new)
    allow(Lich::Common::GUI::ConversionUI).to receive(:conversion_needed?).and_return(false)

    # Mock AccountManagerUI with proper constructor
    account_manager_ui_class = Class.new do
      def initialize(data_dir)
        # Accept data_dir parameter
      end
    end
    stub_const("Lich::Common::GUI::AccountManagerUI", account_manager_ui_class)
    allow(Lich::Common::GUI::AccountManagerUI).to receive(:new).with(data_dir).and_return(account_manager_ui)

    # Mock SavedLoginTab with proper constructor
    saved_login_tab_class = Class.new do
      def initialize(window, entry_data, theme_state, tab_layout_state, autosort_state, default_icon, callbacks)
        # Accept all parameters
      end
    end
    stub_const("Lich::Common::GUI::SavedLoginTab", saved_login_tab_class)
    allow(Lich::Common::GUI::SavedLoginTab).to receive(:new).with(any_args).and_return(saved_login_tab)

    # Mock ManualLoginTab with proper constructor
    manual_login_tab_class = Class.new do
      def initialize(window, entry_data, theme_state, default_icon, callbacks)
        # Accept all parameters
      end
    end
    stub_const("Lich::Common::GUI::ManualLoginTab", manual_login_tab_class)
    allow(Lich::Common::GUI::ManualLoginTab).to receive(:new).with(any_args).and_return(manual_login_tab)

    # Mock Utilities as a module
    stub_const("Lich::Common::GUI::Utilities", Module.new)
    allow(Lich::Common::GUI::Utilities).to receive(:create_message_dialog).and_return(->(_) {})

    # Mock Gtk as a module
    stub_const("Gtk", Module.new)
    allow(Gtk).to receive(:queue) { |&block| block.call if block }
    allow(Gtk).to receive(:main_quit)

    # Mock Gtk classes
    stub_const("Gtk::Notebook", Class.new)
    allow(Gtk::Notebook).to receive(:new).and_return(notebook)
    allow(notebook).to receive(:override_background_color)
    allow(notebook).to receive(:append_page)
    allow(notebook).to receive(:set_tab_pos)

    stub_const("Gtk::Window", Class.new)
    allow(Gtk::Window).to receive(:new).and_return(window)
    allow(window).to receive(:set_icon)
    allow(window).to receive(:title=)
    allow(window).to receive(:border_width=)
    allow(window).to receive(:add)
    allow(window).to receive(:signal_connect).and_yield
    allow(window).to receive(:default_width=)
    allow(window).to receive(:default_height=)
    allow(window).to receive(:override_background_color)
    allow(window).to receive(:show_all)

    stub_const("Gtk::Label", Class.new)
    allow(Gtk::Label).to receive(:new).and_return(double("Label"))

    stub_const("Gtk::Box", Class.new)
    allow(Gtk::Box).to receive(:new).and_return(double("Box", border_width: nil, pack_start: nil))

    stub_const("Gtk::Button", Class.new)

    # Mock Gdk as a module
    stub_const("Gdk", Module.new)
    stub_const("Gdk::RGBA", Class.new)
    allow(Gdk::RGBA).to receive(:parse).and_return(double("RGBA"))

    # Setup instance variables
    test_instance.instance_variable_set(:@done, true) # Skip wait_until loop
    test_instance.instance_variable_set(:@save_entry_data, false)
    test_instance.instance_variable_set(:@launch_data, nil)
    test_instance.instance_variable_set(:@entry_data, entry_data)

    # Skip GUI setup by mocking methods
    allow(test_instance).to receive(:initialize_login_state) do
      # Set up instance variables that would be set by initialize_login_state
      test_instance.instance_variable_set(:@account_manager_ui, account_manager_ui)
      test_instance.instance_variable_set(:@entry_data, entry_data)
    end

    allow(test_instance).to receive(:setup_gui_window) do
      # Set up instance variables that would be set by setup_gui_window
      test_instance.instance_variable_set(:@window, window)
      test_instance.instance_variable_set(:@custom_launch_entry, custom_launch_entry)
      test_instance.instance_variable_set(:@custom_launch_dir, custom_launch_dir)
      test_instance.instance_variable_set(:@bonded_pair_char, bonded_pair_char)
      test_instance.instance_variable_set(:@bonded_pair_inst, bonded_pair_inst)
      test_instance.instance_variable_set(:@slider_box, slider_box)
      test_instance.instance_variable_set(:@notebook, notebook)
      test_instance.instance_variable_set(:@saved_login_ui, saved_login_ui)
      test_instance.instance_variable_set(:@manual_login_ui, manual_login_ui)
    end

    # Mock wait_until method
    allow(test_instance).to receive(:wait_until).and_yield

    # Mock Lich module methods
    allow(Lich).to receive(:track_autosort_state).and_return(false)
    allow(Lich).to receive(:track_layout_state).and_return(false)
    allow(Lich).to receive(:track_dark_mode).and_return(false)
    allow(Lich).to receive(:log)
  end

  after do
    # Clean up test directory
    FileUtils.rm_rf(data_dir)
  end

  context "when initializing login state" do
    before do
      # Allow initialize_login_state to run normally for these tests
      allow(test_instance).to receive(:initialize_login_state).and_call_original

      # But still skip setup_gui_window
      allow(test_instance).to receive(:setup_gui_window)
    end

    it "loads saved entries from YamlState" do
      # Test that YamlState.load_saved_entries is called with correct parameters
      expect(Lich::Common::GUI::YamlState).to receive(:load_saved_entries).with(DATA_DIR, anything)

      # Call method under test, but rescue exit
      begin
        test_instance.gui_login
      rescue SystemExit
        # Expected exit
      end
    end

    it "initializes accessibility support when available" do
      # Test that Accessibility.initialize_accessibility is called when defined
      expect(Lich::Common::GUI::Accessibility).to receive(:initialize_accessibility)

      # Call method under test, but rescue exit
      begin
        test_instance.gui_login
      rescue SystemExit
        # Expected exit
      end
    end
  end

  context "when saving entry data" do
    it "saves entry data when changes are made" do
      # Set save_entry_data to true
      test_instance.instance_variable_set(:@save_entry_data, true)
      test_instance.instance_variable_set(:@entry_data, entry_data)

      # Test that YamlState.save_entries is called when @save_entry_data is true
      expect(Lich::Common::GUI::YamlState).to receive(:save_entries).with(DATA_DIR, entry_data)

      # Call method under test, but rescue exit
      begin
        test_instance.gui_login
      rescue SystemExit
        # Expected exit
      end
    end

    it "doesn't save entry data when no changes are made" do
      # Set save_entry_data to false
      test_instance.instance_variable_set(:@save_entry_data, false)

      # Test that YamlState.save_entries is not called when @save_entry_data is false
      expect(Lich::Common::GUI::YamlState).not_to receive(:save_entries)

      # Call method under test, but rescue exit
      begin
        test_instance.gui_login
      rescue SystemExit
        # Expected exit
      end
    end
  end

  context "when returning launch data" do
    it "returns launch data when available" do
      # Set launch_data
      test_instance.instance_variable_set(:@launch_data, launch_data)

      # Test that launch data is returned when @launch_data is set
      expect(test_instance.gui_login).to eq(launch_data)
    end

    it "exits when no launch data is available" do
      # Set launch_data to nil
      test_instance.instance_variable_set(:@launch_data, nil)

      # Test that the application exits when @launch_data is nil
      expect { test_instance.gui_login }.to raise_error(SystemExit)
    end
  end
end
