# frozen_string_literal: true

# Lich5 carveout - manual login screen for GUI
#
# This file handles the "Manual Entry" tab functionality for the Lich GUI login system.
# It is loaded as part of the gui_login method's Gtk queue block.

# Initialize variables
@launch_data = nil

# Create user ID and password entry fields
user_id_entry = Gtk::Entry.new
pass_entry = Gtk::Entry.new
pass_entry.visibility = false

# Create login table layout
login_table = Gtk::Table.new(2, 2, false)
login_table.attach(Gtk::Label.new('User ID:'), 0, 1, 0, 1, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)
login_table.attach(user_id_entry, 1, 2, 0, 1, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)
login_table.attach(Gtk::Label.new('Password:'), 0, 1, 1, 2, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)
login_table.attach(pass_entry, 1, 2, 1, 2, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)

# Create connect and disconnect buttons
disconnect_button = Lich::Common::GUI::Components.create_button(label: ' Disconnect ')
disconnect_button.sensitive = false

connect_button = Lich::Common::GUI::Components.create_button(label: ' Connect ')

# Create button box for login controls
login_button_box = Lich::Common::GUI::Components.create_button_box(
  [connect_button, disconnect_button],
  expand: false,
  fill: false,
  padding: 5
)

# Create list store and tree view for character selection
liststore = Gtk::ListStore.new(String, String, String, String)
liststore.set_sort_column_id(1, :ascending)

renderer = Gtk::CellRendererText.new

treeview = Gtk::TreeView.new(liststore)
treeview.height_request = 160

# Add game column
col = Gtk::TreeViewColumn.new("Game", renderer, text: 1)
col.resizable = true
treeview.append_column(col)

# Add character column
col = Gtk::TreeViewColumn.new("Character", renderer, text: 3)
col.resizable = true
treeview.append_column(col)

# Create scrolled window for tree view
sw = Gtk::ScrolledWindow.new
sw.set_policy(:automatic, :automatic)
sw.add(treeview)

# Create frontend selection radio buttons
stormfront_option = Gtk::RadioButton.new(label: 'Wrayth')
wizard_option = Gtk::RadioButton.new(label: 'Wizard', member: stormfront_option)
avalon_option = Gtk::RadioButton.new(label: 'Avalon', member: stormfront_option)
suks_option = Gtk::RadioButton.new(label: 'suks', member: stormfront_option)

# Create frontend selection box
frontend_box = Gtk::Box.new(:horizontal, 10)
frontend_box.pack_start(stormfront_option, expand: false, fill: false, padding: 0)
frontend_box.pack_start(wizard_option, expand: false, fill: false, padding: 0)
if RUBY_PLATFORM =~ /darwin/i
  frontend_box.pack_start(avalon_option, expand: false, fill: false, padding: 0)
end
# frontend_box.pack_start(suks_option, false, false, 0)

# Create custom launch options
custom_launch_option = Gtk::CheckButton.new('Custom launch command')
@custom_launch_entry = Gtk::ComboBoxText.new(entry: true)
@custom_launch_entry.child.set_placeholder_text("(enter custom launch command)")
@custom_launch_entry.append_text("Wizard.Exe /GGS /H127.0.0.1 /P%port% /K%key%")
@custom_launch_entry.append_text("Stormfront.exe /GGS/Hlocalhost/P%port%/K%key%")
@custom_launch_dir = Gtk::ComboBoxText.new(entry: true)
@custom_launch_dir.child.set_placeholder_text("(enter working directory for command)")
@custom_launch_dir.append_text("../wizard")
@custom_launch_dir.append_text("../StormFront")

# Create quick entry save option
@make_quick_option = Gtk::CheckButton.new('Save this info for quick game entry')

# Create play button
play_button = Lich::Common::GUI::Components.create_button(label: ' Play ')
play_button.sensitive = false

# Create play button box
play_button_box = Lich::Common::GUI::Components.create_button_box(
  [play_button],
  expand: false,
  fill: false,
  padding: 5
)

# Create main tab container
@game_entry_tab = Gtk::Box.new(:vertical)
@game_entry_tab.border_width = 5
@game_entry_tab.pack_start(login_table, expand: false, fill: false, padding: 0)
@game_entry_tab.pack_start(login_button_box, expand: false, fill: false, padding: 0)
@game_entry_tab.pack_start(sw, expand: true, fill: true, padding: 3)
@game_entry_tab.pack_start(frontend_box, expand: false, fill: false, padding: 3)
@game_entry_tab.pack_start(custom_launch_option, expand: false, fill: false, padding: 3)
@game_entry_tab.pack_start(@custom_launch_entry, expand: false, fill: false, padding: 3)
@game_entry_tab.pack_start(@custom_launch_dir, expand: false, fill: false, padding: 3)
@game_entry_tab.pack_start(@make_quick_option, expand: false, fill: false, padding: 3)
@game_entry_tab.pack_start(play_button_box, expand: false, fill: false, padding: 3)

# Custom launch option toggle handler
custom_launch_option.signal_connect('toggled') {
  @custom_launch_entry.visible = custom_launch_option.active?
  @custom_launch_dir.visible = custom_launch_option.active?
}

# Avalon option toggle handler
avalon_option.signal_connect('toggled') {
  if avalon_option.active?
    custom_launch_option.active = false
    custom_launch_option.sensitive = false
  else
    custom_launch_option.sensitive = true
  end
}

# Connect button click handler
connect_button.signal_connect('clicked') {
  connect_button.sensitive = false
  user_id_entry.sensitive = false
  pass_entry.sensitive = false
  iter = liststore.append
  iter[1] = 'working...'
  Gtk.queue {
    begin
      # Authenticate with legacy mode
      login_info = Lich::Common::GUI::Authentication.authenticate(
        account: user_id_entry.text || argv.account,
        password: pass_entry.text || argv.password,
        legacy: true
      )
    end
    if login_info.to_s =~ /error/i
      @msgbox.call "\nSomething went wrong... probably invalid \nuser id and / or password.\n\nserver response: #{login_info}"
      connect_button.sensitive = true
      disconnect_button.sensitive = false
      user_id_entry.sensitive = true
      pass_entry.sensitive = true
    else
      # Populate character list
      liststore.clear
      login_info.each do |row|
        iter = liststore.append
        iter[0] = row[:game_code]
        iter[1] = row[:game_name]
        iter[2] = row[:char_code]
        iter[3] = row[:char_name]
      end
      disconnect_button.sensitive = true
    end
    true
  }
}

# Tree view selection handler
treeview.signal_connect('cursor-changed') {
  play_button.sensitive = true
}

# Disconnect button click handler
disconnect_button.signal_connect('clicked') {
  disconnect_button.sensitive = false
  play_button.sensitive = false
  liststore.clear
  connect_button.sensitive = true
  user_id_entry.sensitive = true
  pass_entry.sensitive = true
}

# Play button click handler
play_button.signal_connect('clicked') {
  play_button.sensitive = false
  game_code = treeview.selection.selected[0]
  char_name = treeview.selection.selected[3]

  # Authenticate and get launch data
  launch_data_hash = Lich::Common::GUI::Authentication.authenticate(
    account: user_id_entry.text,
    password: pass_entry.text,
    character: char_name,
    game_code: game_code
  )

  # Determine frontend type
  frontend = if wizard_option.active?
               'wizard'
             elsif avalon_option.active?
               'avalon'
             elsif suks_option.active?
               'suks'
             else
               'stormfront'
             end

  # Get custom launch settings
  custom_launch = custom_launch_option.active? ? @custom_launch_entry.child.text : nil
  custom_launch_dir = (custom_launch_option.active? && !@custom_launch_dir.child.text.empty?) ? @custom_launch_dir.child.text : nil

  # Prepare launch data
  @launch_data = Lich::Common::GUI::Authentication.prepare_launch_data(
    launch_data_hash,
    frontend,
    custom_launch,
    custom_launch_dir
  )

  # Save entry data if requested
  if @make_quick_option.active?
    entry_data = Lich::Common::GUI::Authentication.create_entry_data(
      char_name: treeview.selection.selected[3],
      game_code: treeview.selection.selected[0],
      game_name: treeview.selection.selected[1],
      user_id: user_id_entry.text,
      password: pass_entry.text,
      frontend: frontend,
      custom_launch: custom_launch,
      custom_launch_dir: custom_launch_dir
    )

    @entry_data.push entry_data
    @save_entry_data = true
  end

  # Close window if launch data is available
  if @launch_data
    user_id_entry.text = String.new
    pass_entry.text = String.new
    @window.destroy
    @done = true
  else
    disconnect_button.sensitive = false
    play_button.sensitive = false
    connect_button.sensitive = true
    user_id_entry.sensitive = true
    pass_entry.sensitive = true
  end
}

# User ID entry key handler
user_id_entry.signal_connect('activate') {
  pass_entry.grab_focus
}

# Password entry key handler
pass_entry.signal_connect('activate') {
  connect_button.clicked
}
