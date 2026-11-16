# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'
require_relative '../../../lib/common/script_scope/gtk/dialogs'
require_relative '../../../lib/common/script_scope/gtk/displays'

# The P14 share of the text boundary (1845:RC13): MessageDialog#initialize and
# ProgressBar#set_text turn binary-tagged UTF-8 into UTF-8 and refuse other
# non-UTF-8 text at the call, as the P12 and P13 text setters do (1843:RC19),
# instead of at the next publication.
RSpec.describe 'script compatibility dialog and progress text' do
  port_class = Class.new do
    attr_reader :sets, :created, :modals

    def initialize
      @sets = []
      @created = []
      @modals = []
    end

    def create(type, props)
      @created << [type, props]
      Object.new
    end

    def attach(*) = nil
    def detach(*) = nil
    def schema(type) = Lich::WebUI::Contract.schema(type)
    def bind(*) = 'binding'
    def set(_handle, property, value) = @sets << [property, value]
    def destroy(_handle) = nil

    def modal(**options)
      @modals << options
      Lich::WebUI::Future.new
    end
  end

  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('dialog_progress_text.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:cafe) { 'caf'.b + [0xC3, 0xA9].pack('C*') }
  let(:accepted) { cafe.dup.force_encoding(Encoding::UTF_8) }
  let(:rejected) do
    [
      'caf'.b + [0xFF].pack('C*'),
      'caf'.dup.force_encoding(Encoding::ISO_8859_1) + [0xE9].pack('C*').force_encoding(Encoding::ISO_8859_1),
      'caf'.dup.force_encoding(Encoding::ISO_8859_1) + [0xC3, 0xA9].pack('C*').force_encoding(Encoding::ISO_8859_1),
      'hi'.encode(Encoding::UTF_16LE),
      ('caf'.b + [0xFF].pack('C*')).force_encoding(Encoding::UTF_8)
    ]
  end

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| work.call })
    allow(Lich).to receive(:log)
    allow(gtk).to receive(:session) { session }
  end

  def dialog(parent, message)
    gtk::MessageDialog.new(parent: parent, flags: [], type: :info, buttons: :ok, message: message)
  end

  describe 'ProgressBar#set_text' do
    %i[set_text text=].each do |setter|
      it "re-tags binary-tagged UTF-8 and refuses other non-UTF-8 text at #{setter}" do
        bar = gtk::ProgressBar.new
        bar.set_show_text(true)
        bar.materialize
        bar.set_text('old')
        published = port.sets.dup

        rejected.each do |text|
          expect { bar.public_send(setter, text) }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
        end
        expect(bar.text).to eq('old')
        expect(port.sets).to eq(published)

        bar.public_send(setter, cafe)
        expect([bar.text, bar.text.encoding]).to eq([accepted, Encoding::UTF_8])
        expect(port.sets.last).to eq([:label, accepted])
        expect(port.sets.last.last.encoding).to eq(Encoding::UTF_8)
      end
    end

    it 'keeps nil selecting the percentage text and still bounds the length' do
      bar = gtk::ProgressBar.new
      bar.set_show_text(true)
      bar.set_text('old')
      bar.set_text(nil)
      expect(bar.text).to be_nil
      expect { bar.set_text('x' * (Lich::WebUI::Contract::BOUNDS[:short_text] + 1)) }
        .to raise_error(gtk::UnsupportedOperation, /operation=text=/)
      expect { bar.set_text(3) }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
      expect(bar.text).to be_nil
    end
  end

  describe 'MessageDialog#initialize' do
    it 'refuses non-UTF-8 message text at construction and leaves the parent without a dialog' do
      parent = gtk::Window.new('parent')
      rejected.each do |text|
        expect { dialog(parent, text) }.to raise_error(gtk::UnsupportedOperation, /operation=new/)
      end
      expect(parent.instance_variable_get(:@dialogs)).to be_nil
    end

    it 're-tags binary-tagged UTF-8 and publishes it as UTF-8 body text' do
      parent = gtk::Window.new('parent')
      built = dialog(parent, cafe)
      built.show_all

      body = port.modals.last[:body]
      expect([body, body.encoding]).to eq([accepted, Encoding::UTF_8])
    end

    it 'still converts non-String messages with String()' do
      parent = gtk::Window.new('parent')
      dialog(parent, 42).show_all
      expect(port.modals.last[:body]).to eq('42')
    end
  end
end
