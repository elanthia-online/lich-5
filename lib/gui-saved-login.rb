# Lich5 carveout for GUI window - saved game info in tabbed format
#
# quick game entry tab
# this file is intended to load as part of the loginGUI Gtk queue block method
# it is a sequential stream presently, so do not (yet) modify to class / module

Gtk::Settings.default.gtk_application_prefer_dark_theme = true if @theme_state == true

if @entry_data.empty?
  box = Gtk::Box.new(:horizontal)
  box.pack_start(Gtk::Label.new('You have no saved login info.'), :expand => true, :fill => true, :padding => 5)
  @quick_game_entry_tab = Gtk::Box.new(:vertical)
  @quick_game_entry_tab.border_width = 5
  @quick_game_entry_tab.pack_start(box, :expand => true, :fill => true, :padding => 0)
else
  last_user_id = nil
  account_array = []

  if @tab_layout_state == true

    @account_book = Gtk::Notebook.new
    @account_book.set_tab_pos(:left)
    @account_book.show_border = true

    unless @theme_state == true
      lightgrey = Gdk::RGBA::parse("#d3d3d3")
      @account_book.override_background_color(:normal, lightgrey)

      @tab_provider = Gtk::CssProvider.new
      @tab_provider.load(data: "tab { background-image: none; background-color: silver; }\
                          tab:hover { background-color: darkgrey; }")
    end

  account_array = @entry_data.map { |x| x.values[3] }.uniq
  account_array.each { |account|
    last_game_name = nil
    account_box = Gtk::Box.new(:vertical, 0)
    @entry_data.each { |login_info|
      next if login_info[:user_id] != account

      if login_info[:game_name] != last_game_name
        horizontal_separator = Gtk::Separator.new(:horizontal)
        account_box.pack_start(horizontal_separator, :expand => false, :fill => false, :padding => 3)
      end
      last_game_name = login_info[:game_name]

      realm = ''

      if login_info[:game_code]  =~ /^GS3$/
        realm = 'GS Prime'
      elsif login_info[:game_code] =~ /^GSX$/
        realm = 'GS Platinum'
      elsif login_info[:game_code] =~ /^GST$/
        realm = 'GS Test'
      elsif login_info[:game_code] =~ /^GSF$/
        realm = 'GS Shattered'
      elsif login_info[:game_code] =~ /^DR$/
        realm = 'DR Prime'
      elsif login_info[:game_code] =~ /^DRX$/
        realm = 'DR Platinum'
      elsif login_info[:game_code] =~ /^DRT$/
        realm = 'DR Test'
      elsif login_info[:game_code] =~ /^DRF$/
        realm = 'DR Fallen'
      else
        realm = 'Unknown'
      end

        @button_provider = Gtk::CssProvider.new
        @button_provider.load(data:
            "button { font-size: 14px; padding-top: 0px; \
                  padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px; \
                  background-image: none; }\
                  button:hover { background-color: darkgrey; } ")

        @play_button = Gtk::Button.new()
        char_label = Gtk::Label.new("#{realm} - #{login_info[:char_name]}")
        char_label = Gtk::Label.new("#{login_info[:char_name]}")
        char_label.set_width_chars(15)
        fe_label = Gtk::Label.new("(#{login_info[:frontend].capitalize})")
        fe_label.set_width_chars(10)
        instance_label = Gtk::Label.new("#{realm}")
        instance_label.set_width_chars(10)
        char_label.set_alignment(0, 0.5)
        button_row = Gtk::Paned.new(:horizontal)
        button_inset = Gtk::Paned.new(:horizontal)
        button_inset.pack1(instance_label, :shrink => false)
        button_inset.pack2(fe_label, :shrink => false)
        button_row.pack1(char_label, :shrink => false)
        button_row.pack2(button_inset, :shrink => false)

        @play_button.add(button_row)
        @play_button.set_alignment(0.0, 0.5)
        @remove_button = Gtk::Button.new()
        remove_label = Gtk::Label.new('<span foreground="red"><b>Remove</b></span>')
        remove_label.use_markup = true
        remove_label.set_width_chars(10)
        @remove_button.add(remove_label)

        @remove_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
        @play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
        @account_book.style_context.add_provider(@tab_provider, Gtk::StyleProvider::PRIORITY_USER) unless @theme_state == true

        char_box = Gtk::Box.new(:horizontal)
        char_box.pack_end(@remove_button, :expand => true, :fill => false, :padding => 0)
        char_box.pack_start(@play_button, :expand => true, :fill => true, :padding => 0)
        account_box.pack_start(char_box, :expand => false, :fill => false, :padding => 0)

        @play_button.signal_connect('button-release-event') { |owner, ev|
          if (ev.event_type == Gdk::EventType::BUTTON_RELEASE)
            if (ev.button == 1)
              @play_button.sensitive = false
              launch_data_hash = EAccess.auth(
                account: login_info[:user_id],
                password: login_info[:password],
                character: login_info[:char_name],
                game_code: login_info[:game_code]
              )
              launch_data = launch_data_hash.map { |k, v| "#{k.upcase}=#{v}" }
              if login_info[:frontend] == 'wizard'
                launch_data.collect! { |line| line.sub(/GAMEFILE=.+/, 'GAMEFILE=WIZARD.EXE').sub(/GAME=.+/, 'GAME=WIZ').sub(/FULLGAMENAME=.+/, 'FULLGAMENAME=Wizard Front End') }
              elsif login_info[:frontend] == 'avalon'
                launch_data.collect! { |line| line.sub(/GAME=.+/, 'GAME=AVALON') }
              end
              if login_info[:custom_launch]
                launch_data.push "CUSTOMLAUNCH=#{login_info[:custom_launch]}"
                if login_info[:custom_launch_dir]
                  launch_data.push "CUSTOMLAUNCHDIR=#{login_info[:custom_launch_dir]}"
                end
              end
              @launch_data = launch_data
              @window.destroy
              @done = true
            elsif (ev.button == 3)
              pp "I would be adding to a team tab"
            end
          end
        }

        @remove_button.signal_connect('button-release-event') { |owner, ev|
          if (ev.event_type == Gdk::EventType::BUTTON_RELEASE) and (ev.button == 1)
            if (ev.state.inspect =~ /shift-mask/)
              @entry_data.delete(login_info)
              @save_entry_data = true
              char_box.visible = false
            else
              dialog = Gtk::MessageDialog.new(:parent => nil, :flags => :modal, :type => :question, :buttons => :yes_no, :message => "Delete record?")
              dialog.title = "Confirm"
              dialog.set_icon(@default_icon)
              response = nil
              response = dialog.run
              dialog.destroy
              if response == Gtk::ResponseType::YES
                @entry_data.delete(login_info)
                @save_entry_data = true
                char_box.visible = false
              end
            end
          end
        }
      }
      @account_book.append_page(account_box, Gtk::Label.new(account.upcase))
      @account_book.set_tab_reorderable(account_box, true)


    }
    quick_sw = Gtk::ScrolledWindow.new
    quick_sw.set_policy(:automatic, :automatic)
    quick_sw.add(@account_book)

  else
    quick_box = Gtk::Box.new(:vertical, 0)
    @entry_data.each { |login_info|
      if login_info[:user_id].downcase != last_user_id
        last_user_id = login_info[:user_id].downcase
        quick_box.pack_start(Gtk::Label.new("Account: " + last_user_id), :expand => false, :fill => false, :padding => 6)
      end

      label = Gtk::Label.new("#{login_info[:char_name]} (#{login_info[:game_name]}, #{login_info[:frontend]})")
      play_button = Gtk::Button.new(:label => 'Play')
      remove_button = Gtk::Button.new(:label => 'X')

      @button_provider = Gtk::CssProvider.new
      @button_provider.load(data:
        "button { font-size: 12px; padding-top: 0px; \
                  padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px; \
                  background-image: none; }\
                  button:hover { background-color: darkgrey; } ")

      remove_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
      play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)

      char_box = Gtk::Box.new(:horizontal)
      char_box.pack_start(label, :expand => false, :fill => false, :padding => 0)
      char_box.pack_end(remove_button, :expand => false, :fill => false, :padding => 0)
      char_box.pack_end(play_button,:expand => false, :fill => false, :padding => 0)
      quick_box.pack_start(char_box, :expand => false, :fill => false, :padding => 0)
      play_button.signal_connect('button-release-event') { |owner, ev|
        if (ev.event_type == Gdk::EventType::BUTTON_RELEASE)
          if (ev.button == 1)
            play_button.sensitive = false
            launch_data_hash = EAccess.auth(
              account: login_info[:user_id],
              password: login_info[:password],
              character: login_info[:char_name],
              game_code: login_info[:game_code]
            )
            launch_data = launch_data_hash.map { |k, v| "#{k.upcase}=#{v}" }
            if login_info[:frontend] == 'wizard'
              launch_data.collect! { |line| line.sub(/GAMEFILE=.+/, 'GAMEFILE=WIZARD.EXE').sub(/GAME=.+/, 'GAME=WIZ').sub(/FULLGAMENAME=.+/, 'FULLGAMENAME=Wizard Front End') }
            elsif login_info[:frontend] == 'avalon'
              launch_data.collect! { |line| line.sub(/GAME=.+/, 'GAME=AVALON') }
            end
            if login_info[:custom_launch]
              launch_data.push "CUSTOMLAUNCH=#{login_info[:custom_launch]}"
              if login_info[:custom_launch_dir]
                launch_data.push "CUSTOMLAUNCHDIR=#{login_info[:custom_launch_dir]}"
              end
            end
            @launch_data = launch_data
            @window.destroy
            @done = true
          elsif (ev.button == 3)
            pp "I would be adding to a team tab"
          end
        end
      }

      remove_button.signal_connect('button-release-event') { |owner, ev|
        if (ev.event_type == Gdk::EventType::BUTTON_RELEASE) and (ev.button == 1)
          if (ev.state.inspect =~ /shift-mask/)
            @entry_data.delete(login_info)
            @save_entry_data = true
            char_box.visible = false
          else
            dialog = Gtk::MessageDialog.new(:parent => nil, :flags => :modal, :type => :question, :buttons => :yes_no, :message => "Delete record?")
            dialog.title = "Confirm"
            dialog.set_icon(@default_icon)
            response = nil
            response = dialog.run
            dialog.destroy
            if response == Gtk::ResponseType::YES
              @entry_data.delete(login_info)
              @save_entry_data = true
              char_box.visible = false
            end
          end
        end
      }
    }

     adjustment = Gtk::Adjustment.new(0, 0, 1000, 5, 20, 500)
     quick_vp = Gtk::Viewport.new(adjustment, adjustment)
     quick_vp.add(quick_box)

     quick_sw = Gtk::ScrolledWindow.new
     quick_sw.set_policy(:automatic, :automatic)
     quick_sw.add(quick_vp)

  end

  @togglebutton_provider = Gtk::CssProvider.new
  @togglebutton_provider.load(data:
    "button { font-size: 12px; padding-top: 0px; \
              padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px; \
              background-image: none; }\
              button:hover { background-color: darkgrey; } ")

# Tabbed character management stuff

  add_character_pane = Gtk::Paned.new(:horizontal)
  add_instance_pane = Gtk::Paned.new(:horizontal)

  add_char_label = Gtk::Label.new("Character")
  add_char_label.set_width_chars(15)
  add_char_entry = Gtk::Entry.new
  add_char_entry.set_width_chars(15)
  add_character_pane.add1(add_char_label)
  add_character_pane.pack2(add_char_entry)

  add_inst_select = Gtk::ComboBoxEntry.new()
  add_inst_select.child.text = "Prime"
  add_inst_select.append_text("Prime")
  add_inst_select.append_text("Platinum")
  add_inst_select.append_text("Shattered")
  add_inst_select.append_text("Test")
  add_inst_label = Gtk::Label.new("Instance")
  add_inst_label.set_width_chars(15)

  add_instance_pane.add1(add_inst_label)
  add_instance_pane.add2(add_inst_select)

  q_stormfront_option = Gtk::RadioButton.new(:label => 'Stormfront')
  q_wizard_option = Gtk::RadioButton.new(:label => 'Wizard', :member => q_stormfront_option)
  q_avalon_option = Gtk::RadioButton.new(:label => 'Avalon', :member => q_stormfront_option)

  add_char_button = Gtk::Button.new(:label => "Add to this account")
  q_frontend_box = Gtk::Box.new(:horizontal, 10)
  if RUBY_PLATFORM =~ /darwin/i
    q_frontend_box.pack_end(q_avalon_option, :expand => false, :fill => false, :padding => 0)
  else
    q_frontend_box.pack_end(q_wizard_option, :expand => false, :fill => false, :padding => 0)
    q_frontend_box.pack_end(q_stormfront_option, :expand => false, :fill => false, :padding => 0)
  end

  @bonded_pair_char = Gtk::Paned.new(:horizontal)
  @bonded_pair_char.set_position(350)
  @bonded_pair_char.add1(add_character_pane)
  @bonded_pair_char.add2(q_frontend_box)

  @bonded_pair_inst = Gtk::Paned.new(:horizontal)
  @bonded_pair_inst.set_position(350)
  @bonded_pair_inst.add1(add_instance_pane)
  @bonded_pair_inst.add2(add_char_button)

  @quick_game_entry_tab = Gtk::Box.new(:vertical)
  @quick_game_entry_tab.border_width = 5
  @quick_game_entry_tab.pack_start(quick_sw, :expand => true, :fill => true, :padding => 5)

# Only show Tab / Account character management if tab_layout_state is chosen
# Tab / Account character management is not complete - commenting out
=begin
  if @tab_layout_state == 'on'
    extro_option = Gtk::ToggleButton.new(:label => 'Add character to this tab / account')
    extro_option.style_context.add_provider(@togglebutton_provider, Gtk::StyleProvider::PRIORITY_USER)
    @quick_game_entry_tab.pack_start(extro_option, :expand => false, :fill => false, :padding => 5)
    @quick_game_entry_tab.pack_start(@bonded_pair_char, :expand => false, :fill => false, :padding => 5)
    @quick_game_entry_tab.pack_start(@bonded_pair_inst, :expand => false, :fill => false, :padding => 5)

    @bonded_pair_char.visible = false
    @bonded_pair_inst.visible = false

    extro_option.signal_connect('toggled') {
      @bonded_pair_char.visible = extro_option.active?
      @bonded_pair_inst.visible = extro_option.active?
    }
  end
=end
  # Global settings stuff

    @slider_box = Gtk::Box.new(:horizontal, 5)
    theme_select = Gtk::Switch.new
    tab_select = Gtk::Switch.new
    sort_select = Gtk::Switch.new
    theme_select_label = Gtk::Label.new('Dark Theme')
    tab_select_label = Gtk::Label.new('Tab Layout')
    sort_select_label = Gtk::Label.new(' AutoSort   ')
    theme_select.set_active(true) if @theme_state == true
    tab_select.set_active(true) if @tab_layout_state == true
    sort_select.set_active(true) if @autosort_state == true

    @slider_box.pack_start(theme_select, :expand => true, :fill => false, :padding => 0)
    @slider_box.pack_start(theme_select_label, :expand => true, :fill => false, :padding => 0)
    @slider_box.pack_start(tab_select, :expand => true, :fill => false, :padding => 0)
    @slider_box.pack_start(tab_select_label, :expand => true, :fill => false, :padding => 0)
    @slider_box.pack_start(sort_select, :expand => true, :fill => false, :padding => 0)
    @slider_box.pack_start(sort_select_label, :expand => true, :fill => false, :padding => 0)

    @settings_option = Gtk::ToggleButton.new(:label => 'Change global GUI settings')
    @settings_option.style_context.add_provider(@togglebutton_provider, Gtk::StyleProvider::PRIORITY_USER)
    @quick_game_entry_tab.pack_start(@settings_option, :expand => false, :fill => false, :padding => 5)
    @quick_game_entry_tab.pack_start(@slider_box, :expand => false, :fill => false, :padding => 5)

    @slider_box.visible = false

    @settings_option.signal_connect('toggled') {
      @slider_box.visible = @settings_option.active?
    }

    theme_select.signal_connect('notify::active') { |s|
      if theme_select.active?
        Gtk::Settings.default.gtk_application_prefer_dark_theme = true
        @play_button.style_context.remove_provider(@button_provider) if defined?(@button_provider)
        @account_book.style_context.remove_provider(@tab_provider) if defined?(@tab_provider)
        @account_book.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
        @notebook.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
        Lich.track_dark_mode = true
      else
        Gtk::Settings.default.gtk_application_prefer_dark_theme = false
        lightgrey = Gdk::RGBA::parse("#d3d3d3")
        @account_book.override_background_color(:normal, lightgrey)
        @notebook.override_background_color(:normal, lightgrey)
        Lich.track_dark_mode = false
      end
    }

    tab_select.signal_connect('notify::active') { |s|
      Lich.track_layout_state = tab_select.active? ? true : false
    }

    sort_select.signal_connect('notify::active') { |s|
      Lich.track_autosort_state = sort_select.active? ? true : false
    }

end #if
