if defined?(Gtk)
  Gdk.module_eval do
    define_deprecated_singleton_method :screen_height, :warn => "Gdk::screen_height is deprecated; use monitor methods instead" do |_self|
      99999
    end

    define_deprecated_singleton_method :screen_width, :warn => "Gdk::screen_width is deprecated; use monitor methods instead" do |_self|
      99999
    end
  end

  Gtk::Drag.module_eval do
    define_deprecated_const :TARGET_SAME_APP, "Gtk::TargetFlags::SAME_APP"
    define_deprecated_const :DEST_DEFAULT_ALL, "Gtk::DestDefaults::ALL"
  end

  Gtk.module_eval do
    # Deprecation updates to keep gtk3 mostly going in gtk2
    define_deprecated_const(:ComboBoxEntry, nil)
    define_deprecated_const(:Tooltips, nil)

    Gtk::ComboBox.class_eval do
      def append_text(text)
        respond "'Gtk::ComboBox#append_text' is deprecated; use 'Gtk::ComboBoxText#append_text' instead"
      end
    end

    class Gtk::ComboBoxEntry < Gtk::ComboBoxText
      def initialize()
        respond "'Gtk::ComboBoxEntry' is deprecated; use 'Gtk::ComboBoxText(:entry => true)' instead"
        super(:entry => true)
      end
    end

    Gtk::Entry.class_eval do
      def set_text(text)
        if text.nil?
          respond "'Gtk::Entry#set_text' no longer accepts nil values; fix me"
          text = ""
        end
        parent.set_text(text)
        return self
      end
    end

    Gtk::HBox.class_eval do
      define_deprecated_singleton_method :new, :warn => "Use 'Gtk::Box.new(:horizontal, spacing)'." do |_self, homogeneous, spacing|
        respond "'Gtk::Hbox' is deprecated; use 'Gtk::Box.new(:horizontal, spacing)'."
        box = Gtk::Box.new(:horizontal, spacing)
        box.set_homogeneous(homogeneous ? true : false)
        box
      end
    end

    Gtk::Notebook.class_eval do
      def set_tab_border(border)
        respond "'Gtk::Notebook:set_tab_border()' is deprecated; fix me"
        # noop
        return self
      end
    end

    Gtk::ToggleButton.class_eval do
      def set_active(active)
        if active.nil?
          respond "'Gtk::ToggleButton#set_active' no longer accepts nil values; fix me"
          active = false
        end
        parent.set_active(active)
        return self
      end
    end

    class Gtk::Tooltips < Gtk::Tooltip
      def enable
        respond "'Gtk::Tooltips#enable' is deprecated; use 'Gtk::Tooltip' API instead"
        # noop
        return self
      end

      def set_tip(one = nil, two = nil, three = nil)
        respond "'Gtk::Tooltips#set_tip' is deprecated; use 'Gtk::Tooltip' API instead"
        # noop
        return self
      end
    end

    Gtk::VBox.class_eval do
      define_deprecated_singleton_method :new, :warn => "Use 'Gtk::Box.new(:vertical, spacing)'." do |_self, homogeneous, spacing|
        respond "'Gtk::VBox' is deprecated; use 'Gtk::Box.new(:vertical, spacing)' instead"
        box = Gtk::Box.new(:vertical, spacing)
        box.set_homogeneous(homogeneous ? true : false)
        box
      end
    end

    # Calling Gtk API in a thread other than the main thread may cause random segfaults
    def Gtk.queue(&block)
      GLib::Timeout.add(1) {
        begin
          block.call
        rescue
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue SyntaxError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue SystemExit
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          nil
        rescue SecurityError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue ThreadError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue SystemStackError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue Exception
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue ScriptError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue LoadError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue NoMemoryError
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue
          respond "error in Gtk.queue: #{$!}"
          puts "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error in Gtk.queue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
        false # don't repeat timeout
      }
    end
  end
  def gtk_sleep_while_idle()
    sleep 0.01
  end

  unless File.exist?('logo.png')
    File.open('logo.png', 'wb') { |f|
      f.write '
      iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAA
      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'.unpack('m')[0]
    }
  end

  begin
    Gtk.queue {
      @default_icon = GdkPixbuf::Pixbuf.new(:file => 'logo.png')
      # Add a function to call for when GTK is idle
      GLib::Idle.add do
        gtk_sleep_while_idle
      end
    }
  rescue
    nil # fixme
  end

end
