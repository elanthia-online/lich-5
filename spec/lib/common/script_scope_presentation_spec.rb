# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'script compatibility and the core presentation policy' do
  let(:root) { File.expand_path('../../..', __dir__) }
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('policy.lic') }

  # HAVE_GTK is fixed at the first activation, so each policy needs a fresh process.
  def have_gtk_after(setup)
    source = <<~RUBY
      require_relative 'lib/webui'
      require_relative 'lib/common/script'
      #{setup}
      values = [Lich::Common::TRUSTED_SCRIPT_BINDING.call, Lich::Common::Scripting.new.script].map { |scope| eval('HAVE_GTK', scope) }
      abort 'GTK gem loaded' if $LOADED_FEATURES.any? { |path| path.include?('/gtk3') }
      print values.uniq.inspect
    RUBY
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', source, chdir: root)
    expect(status).to be_success, errors
    output
  end

  it 'derives HAVE_GTK from the policy configured before the first activation' do
    expect(have_gtk_after('Lich::WebUI.configure_presentation(enabled: true)')).to eq('[true]')
    expect(have_gtk_after('Lich::WebUI.configure_presentation(enabled: false)')).to eq('[false]')
    expect(have_gtk_after('')).to eq('[false]')
  end

  it 'keeps the value fixed at activation when the policy changes later' do
    setup = 'Lich::Common::ScriptScope.activate!; Lich::WebUI.configure_presentation(enabled: true)'
    expect(have_gtk_after(setup)).to eq('[false]')
  end

  context 'with the scope active' do
    before do
      scope.activate!
      stub_const('Lich::Common::Script', Class.new { def self.current; end })
      allow(Lich::Common::Script).to receive(:current).and_return(owner)
    end

    after { Lich::WebUI.configure_presentation(enabled: nil) }

    it 'resolves the compatibility entrypoints only while presentation is enabled' do
      Lich::WebUI.configure_presentation(enabled: true)
      expect(require('gtk3')).to be(false)
      expect(require('gtk2')).to be(false)

      [false, nil].each do |policy|
        Lich::WebUI.configure_presentation(enabled: policy)
        %w[gtk3 gtk2].each do |feature|
          expect { require feature }.to raise_error(LoadError, /script=policy\.lic .*feature=#{feature} .*presentation is disabled/)
        end
      end
      expect($LOADED_FEATURES.grep(%r{/gtk[23](?:\.rb)?\z})).to be_empty
    end

    it 'keeps refusing native dependencies whatever the policy' do
      [true, false].each do |policy|
        Lich::WebUI.configure_presentation(enabled: policy)
        expect { require 'glib2' }.to raise_error(scope::Gtk::UnsupportedOperation, /native GTK loading is disabled/)
      end
    end

    it 'runs the top of an absolute require of an unactivated gem file but refuses its first native require' do
      Dir.mktmpdir('lich-unactivated-gem') do |dir|
        entry = File.join(dir, 'gems', 'gtk3-3.5.1', 'lib', 'gtk3.rb')
        FileUtils.mkdir_p(File.dirname(entry))
        File.write(entry, "UNACTIVATED_GEM_TOP << :ran\nrequire 'glib2'\nUNACTIVATED_GEM_TOP << :native\n")
        stub_const('UNACTIVATED_GEM_TOP', [])

        expect { require entry }.to raise_error(scope::Gtk::UnsupportedOperation, /feature=glib2 .*native GTK loading is disabled/)
        expect(UNACTIVATED_GEM_TOP).to eq([:ran])
        expect($LOADED_FEATURES.grep(/glib2/)).to be_empty
      end
    end
  end
end
