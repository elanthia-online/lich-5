# frozen_string_literal: true

require_relative '../../spec_helper'

# lib/main/argv_options.rb auto-executes ArgvOptions.process_argv at load
# time, so it cannot be required in isolation. As spec/lib/main/argv_options_spec.rb
# does, lift OptionParser.execute out of the source and eval it into a harness
# so the switches are exercised through the real parser rather than by grepping
# for their `when` lines.
RSpec.describe 'the launcher switches' do
  source_path = File.join(LIB_DIR, 'main', 'argv_options.rb')

  parser_class = Class.new do
    source = File.read(source_path)
    method_body = source[/^(?<ind>[ \t]*)def self\.execute$.*?^\k<ind>end$/m]
    raise 'could not extract OptionParser.execute from argv_options.rb' unless method_body

    module_eval(method_body.sub('def self.execute', 'def execute'))
    # The real one checks the file exists and looks under Wine; the routing
    # only needs the option recorded.
    define_method(:handle_sal_file) { |arg| @argv_options[:sal] = arg }
  end
  define_singleton_method(:parser_class) { parser_class }

  around do |example|
    original_argv = ARGV.dup
    begin
      example.run
    ensure
      ARGV.replace(original_argv)
    end
  end

  it 'recognises --webui, its --webui-dev alias, and --gtk without touching the GTK switches' do
    { '--webui' => :webui, '--webui-dev' => :webui, '--gtk' => :gtk }.each do |switch, choice|
      ARGV.replace([switch])

      options = parser_class.new.execute

      expect(options[:launcher]).to eq(choice), "#{switch} should set launcher to #{choice}"
      expect(options).not_to have_key(:gui)
      expect(options).not_to have_key(:webui_dev)
    end
  end

  it 'records a fixed WebUI port and the no-browser choice for remote play' do
    ARGV.replace(['--webui-port=4321', '--webui-no-browser'])

    options = parser_class.new.execute

    expect(options[:webui_port]).to eq(4321)
    expect(options[:webui_browser]).to be(false)
    expect(options).not_to have_key(:launcher)
  end

  it 'leaves argv_options without a launcher when no switch is given' do
    ARGV.replace(['--gui'])

    expect(parser_class.new.execute).not_to have_key(:launcher)
  end

  it 'reads the one resolved choice at every site instead of re-deriving a flag' do
    # main.rb and lich.rbw run their startup sequences at load time, so the
    # branch order cannot be exercised behaviourally here; the source is the
    # observable fact. What matters is that no site inspects ARGV or a
    # webui_dev option of its own: they all ask Lich.launcher.
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))
    init = File.read(File.join(LIB_DIR, 'init.rb'))
    entrypoint = File.read(File.expand_path('../../../lich.rbw', __dir__))

    webui_branch = main.index('elsif Lich.launcher == :webui')
    gtk_branch = main.index('elsif defined?(Gtk)')
    expect(webui_branch).to be_a(Integer)
    expect(gtk_branch).to be_a(Integer)
    expect(webui_branch).to be < gtk_branch
    expect(main).to include("require File.join(LIB_DIR, 'common', 'gui_login.rb')")
    expect(main).to include('if Lich.launcher == :webui').twice
    expect(init).to include("require File.join(LIB_DIR, 'common', 'launcher_choice.rb')")
    expect(init).to include('elsif Lich.launcher == :webui')
    expect(entrypoint).to include('if defined?(Gtk) && Lich.launcher == :gtk')
    expect([main, init, entrypoint].join).not_to include('webui_dev')
  end

  # The source-order assertions above did not exercise the routing, and the
  # review of 2026-09-17 (R1) found that `--gtk` alone opened nothing: the
  # GTK branch still asked for ARGV.empty? or --gui, and `--gtk` is neither.
  # main.rb runs at load, so the two branch predicates are lifted out of the
  # source and evaluated against the real parser's output.
  describe 'the launcher branches, evaluated' do
    main_source = File.read(File.join(LIB_DIR, 'main', 'main.rb'))
    webui_predicate = main_source[/^\s*elsif (Lich\.launcher == :webui && \(.*?\))$/, 1]
    gtk_predicate = main_source[/^\s*elsif (defined\?\(Gtk\) and \(.*?\))$/, 1]
    raise 'could not extract the launcher predicates from main.rb' unless webui_predicate && gtk_predicate

    harness_class = Class.new do
      def initialize(argv_options, launcher, gtk_loaded)
        @argv_options = argv_options
        @launcher = launcher
        @gtk_loaded = gtk_loaded
      end

      define_method(:opens_webui?) { instance_eval(webui_predicate.gsub('Lich.launcher', '@launcher')) }
      define_method(:opens_gtk?) { instance_eval(gtk_predicate.gsub('defined?(Gtk)', '@gtk_loaded')) }
    end
    define_singleton_method(:harness_class) { harness_class }

    def route(argv, launcher:, gtk_loaded: launcher == :gtk)
      ARGV.replace(argv)
      options = parser_class.new.execute
      harness = harness_class.new(options, launcher, gtk_loaded)
      if harness.opens_webui? then :webui
      elsif harness.opens_gtk? then :gtk
      else :headless
      end
    end

    let(:parser_class) { self.class.parser_class }
    let(:harness_class) { self.class.harness_class }

    it 'opens the GTK launcher for --gtk alone' do
      expect(route(['--gtk'], launcher: :gtk)).to eq(:gtk)
    end

    it 'opens the WebUI launcher for --webui alone and for no arguments under the WebUI default' do
      expect(route(['--webui'], launcher: :webui)).to eq(:webui)
      expect(route([], launcher: :webui)).to eq(:webui)
    end

    it 'follows a persisted GTK choice with no arguments, and --gui under either launcher' do
      expect(route([], launcher: :gtk)).to eq(:gtk)
      expect(route(['--gui'], launcher: :gtk)).to eq(:gtk)
      expect(route(['--gui'], launcher: :webui)).to eq(:webui)
    end

    it 'starts headless for an explicit --no-gui under either launcher' do
      expect(route(['--no-gui'], launcher: :gtk)).to eq(:headless)
      expect(route(['--no-gui'], launcher: :webui)).to eq(:headless)
    end

    # A launcher flag selects which launcher; it does not ask for one. The
    # R1 fix read it as the latter, so any startup with a launcher flag
    # beside it -- Saga's `<file>.sal --gtk --without-frontend
    # --detachable-client=N --saga` (Tysong, 2026-09-17), a `--game=HOST:PORT`
    # proxy, a force mode -- opened the launcher instead of connecting. The
    # launcher opens only when the command line asks for nothing else.
    describe 'a launcher flag beside a session' do
      saga = ['C:\\Users\\Ryan\\AppData\\Local\\Temp\\saga-Pickasso-mu5mjeft.sal', '--gtk', '--without-frontend',
              '--detachable-client=62992', '--saga']
      {
        'Saga'            => saga,
        'a proxy'         => ['--game=lich.example:8000', '--gtk'],
        'a force mode'    => ['--gemstone', '--gtk'],
        'a headless port' => ['--headless', '4000', '--gtk'],
      }.each do |shape, argv|
        it "connects rather than opening a launcher for #{shape}" do
          expect(route(argv, launcher: :gtk)).to eq(:headless)
          swapped = argv.map { |argument| argument == '--gtk' ? '--webui' : argument }
          expect(route(swapped, launcher: :webui)).to eq(:headless)
        end
      end

      it 'still opens the launcher for the flag alone, or the flag with --gui' do
        expect(route(['--gtk'], launcher: :gtk)).to eq(:gtk)
        expect(route(['--webui'], launcher: :webui)).to eq(:webui)
        expect(route(['--webui-dev'], launcher: :webui)).to eq(:webui)
        expect(route(['--game=lich.example:8000', '--gui'], launcher: :webui)).to eq(:webui)
      end
    end

    it 'never opens the GTK launcher when gtk3 did not load' do
      expect(route(['--gtk'], launcher: :gtk, gtk_loaded: false)).to eq(:headless)
    end
  end

  it 'loads gtk3 only when the launcher is GTK' do
    init = File.read(File.join(LIB_DIR, 'init.rb'))
    gtk_require = init.index("require 'gtk3'")
    webui_branch = init.index('elsif Lich.launcher == :webui')

    expect(webui_branch).to be < gtk_require
    expect(init).to match(/elsif Lich\.launcher == :webui\n\s+HAVE_GTK = false/)
  end

  it 'does not falsify GTK availability from the launcher or introduce a shim dependency' do
    launcher = File.read(File.join(LIB_DIR, 'common', 'webui_launcher.rb'))
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))

    expect([launcher, main].join("\n")).not_to match(/HAVE_GTK\s*=\s*false/)
    expect(launcher).not_to include('script_scope/gtk')
    expect(launcher).not_to match(/\bGtk(?:::|\.)/)
  end

  it 'ends the Ruby startup path after a launcher-only browser close' do
    main = File.read(File.join(LIB_DIR, 'main', 'main.rb'))
    browser = File.read(File.join(LIB_DIR, 'webui', 'assets', 'app.js'))
    entrypoint = File.read(File.expand_path('../../../lich.rbw', __dir__))

    expect(browser).to include('window.addEventListener("pagehide", detachPages)')
    expect(browser).to include('type: "detach", page: page.address, generation: page.generation')
    # Comment lines may sit between the two statements.
    expect(main).to match(/@launch_data = webui_launcher\.start\.await_launch\n(?:[ \t]*#.*\n)*[ \t]*next unless @launch_data/)
    expect(entrypoint).to include("else\n  @main_thread.join\nend")
  end
end
