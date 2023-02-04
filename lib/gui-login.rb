# Lich5 Carve out - GTK3 lich-login code stuff

def gui_login

  @autosort_state = Lich.track_autosort_state
  @tab_layout_state = Lich.track_layout_state
  @theme_state = Lich.track_dark_mode

  @launch_data = nil
  if File.exist?("#{DATA_DIR}/entry.dat")
    @entry_data = File.open("#{DATA_DIR}/entry.dat", 'r') { |file|
      begin
        if @autosort_state == true
        # Sort in list by instance name, account name, and then character name
        Marshal.load(file.read.unpack('m').first).sort do |a, b|
          [a[:game_name], a[:user_id], a[:char_name]] <=> [b[:game_name], b[:user_id], b[:char_name]]
        end
        else
        # Sort in list by account name, and then character name (old Lich 4)
          Marshal.load(file.read.unpack('m').first).sort do |a,b|
            [a[:user_id].downcase, a[:char_name]] <=> [b[:user_id].downcase, b[:char_name]]
          end
        end
      rescue
        Array.new
      end
    }
  else
    @entry_data = Array.new
  end
  @save_entry_data = false
  done = false

  Gtk.queue {
    login_server = nil
    @window = nil
    install_tab_loaded = false

    @msgbox = proc { |msg|
      dialog = Gtk::MessageDialog.new(:parent => @window, :flags => Gtk::DialogFlags::DESTROY_WITH_PARENT, :type => Gtk::MessageType::ERROR, :buttons => Gtk::ButtonsType::CLOSE, :message => msg)
      #			dialog.set_icon(default_icon)
      dialog.run
      dialog.destroy
    }
    # the following files are split out to ease interface design
    # they have to be included in the method's Gtk queue block to
    # be used, so they have to be called at this specific point.

    require 'lib/gui-saved-login'
    require 'lib/gui-manual-login'

    #
    # put it together and show the window
    #
    lightgrey = Gdk::RGBA::parse("#d3d3d3")
    @notebook = Gtk::Notebook.new
    @notebook.override_background_color(:normal, lightgrey) unless @theme_state == true
    @notebook.append_page(@quick_game_entry_tab, Gtk::Label.new('Saved Entry'))
    @notebook.append_page(@game_entry_tab, Gtk::Label.new('Manual Entry'))

    @notebook.signal_connect('switch-page') { |who, page, page_num|
      if (page_num == 2) and not install_tab_loaded
        refresh_button.clicked
      end
    }

    #    grey = Gdk::RGBA::parse("#d3d3d3")
    @window = Gtk::Window.new
    @window.set_icon(@default_icon)
    @window.title = "Lich v#{LICH_VERSION}"
    @window.border_width = 5
    @window.add(@notebook)
    @window.signal_connect('delete_event') { @window.destroy; @done = true }
    @window.default_width = 550
    @window.default_height = 550
    @window.show_all

    @custom_launch_entry.visible = false
    @custom_launch_dir.visible = false
    @bonded_pair_char.visible = false
    @bonded_pair_inst.visible = false
    @slider_box.visible = false

    @notebook.set_page(1) if @entry_data.empty?

  }

  wait_until { @done }

  if @save_entry_data
    File.open("#{DATA_DIR}/entry.dat", 'w') { |file|
      file.write([Marshal.dump(@entry_data)].pack('m'))
    }
  end
  @entry_data = nil

  unless !@launch_data.nil?
    Gtk.queue { Gtk.main_quit }
    Lich.log "info: exited without selection"
    exit
  end
end
