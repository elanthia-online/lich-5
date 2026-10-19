# frozen_string_literal: true

require_relative '../spec_helper'

# respond, _respond and Lich::Messaging write text to the frontends. Callers
# use them as the last expression of a method, so their return value becomes
# that method's return value: `return data if ok; Lich::Messaging.msg(...)`
# must return nil, or a caller testing the result sees success. These
# examples pin that contract on the shipped code.
#
# The real methods are read out of lib/global_defs.rb and lib/messaging.rb
# and evaluated into anonymous modules, so spec_helper's global respond,
# _respond and Lich::Messaging stand-ins stay in place for every other file.
module RespondReturnSpecSource
  GLOBAL_DEFS = File.expand_path('../../lib/global_defs.rb', __dir__)
  MESSAGING = File.expand_path('../../lib/messaging.rb', __dir__)

  # Attached detachable frontends the examples control.
  @clients = []
  class << self
    attr_accessor :clients
  end

  # Text one top-level method of lib/global_defs.rb, from its def to the
  # column-0 end. Raises when it is missing or defined twice, so a reformat
  # of the production file fails these examples instead of testing nothing.
  def self.global_def(name)
    lines = File.readlines(GLOBAL_DEFS)
    found = lines.each_index.select { |i| lines[i].match?(/^def #{Regexp.escape(name)}(?:\(|\s|$)/) }
    raise "global_defs.rb: def #{name} missing" if found.empty?
    raise "global_defs.rb: def #{name} defined #{found.size} times" if found.size > 1

    first = found.first
    offset = lines[(first + 1)..].index { |line| line.match?(/^end\s*$/) }
    raise "global_defs.rb: def #{name} terminator missing" unless offset

    [lines[first..(first + offset + 1)].join, first + 1]
  end

  # A module holding the shipped respond, _respond and
  # detachable_clients_respond, with stand-ins for what they call. The
  # stand-in constants are found first because the methods are evaluated
  # with this module as their lexical scope.
  def self.output_module
    mod = Module.new
    mod.const_set(:Script, Module.new { def self.new_script_output(_line); end })
    mod.const_set(:Buffer, Module.new { def self.update(_line, _stream); end })
    mod::Buffer.const_set(:SCRIPT_OUTPUT, 4)
    mod.const_set(:Frontend, Module.new do
      def self.supports_mono? = false
      def self.client = 'stormfront'
    end)
    %w[respond _respond detachable_clients_respond].each do |name|
      source, line = global_def(name)
      mod.module_eval(source, GLOBAL_DEFS, line)
    end
    mod.module_eval do
      def detachable_clients_snapshot = RespondReturnSpecSource.clients.dup
      def detachable_client_unregister(client) = RespondReturnSpecSource.clients.delete(client)
      def monsterbold_start = '<b>'
      def monsterbold_end = '</b>'
      public :respond, :_respond, :detachable_clients_respond
    end
    mod
  end

  # The shipped Lich::Messaging, evaluated inside a sandbox so the real
  # module never replaces spec_helper's recording stand-in. It calls the
  # shipped _respond above.
  def self.messaging
    sandbox = Module.new
    sandbox.const_set(:Frontend, Module.new do
      def self.supports_xml? = false
      def self.supports_gsl? = false
      def self.supports_streams? = false
      def self.supports_mono? = false
    end)
    sandbox.module_eval(File.read(MESSAGING), MESSAGING, 1)
    messaging = sandbox::Lich::Messaging
    raise 'messaging.rb did not define Lich::Messaging in the sandbox' if messaging.equal?(::Lich::Messaging)

    sandbox::Lich.define_singleton_method(:debug_messaging) { false }
    messaging.extend(output_module)
    messaging
  end
end

RSpec.describe 'respond, _respond and Lich::Messaging return values' do
  # A detachable frontend: records what it is sent.
  let(:client_class) do
    Class.new do
      attr_reader :received

      def initialize(alive: true, dies_on_write: false)
        @alive = alive
        @dies_on_write = dies_on_write
        @received = []
      end

      def alive? = @alive

      def puts_main_stream(string)
        @received << string
        @alive = false if @dies_on_write
      end
    end
  end

  let(:output) { Object.new.extend(RespondReturnSpecSource.output_module) }

  before do
    RespondReturnSpecSource.clients = []
    allow($_CLIENT_).to receive(:alive?).and_return(true)
    allow($_CLIENT_).to receive(:puts_main_stream)
  end

  after { RespondReturnSpecSource.clients = [] }

  %i[respond _respond].each do |method|
    describe "##{method}" do
      it 'returns nil with no detachable frontend attached' do
        expect(output.public_send(method, 'hello')).to be_nil
      end

      it 'returns nil with a detachable frontend attached, and still sends it the text' do
        client = client_class.new
        RespondReturnSpecSource.clients = [client]

        expect(output.public_send(method, 'hello')).to be_nil
        expect(client.received).to eq(["hello\r\n"])
      end

      it 'returns nil with several frontends attached' do
        clients = Array.new(3) { client_class.new }
        RespondReturnSpecSource.clients = clients

        expect(output.public_send(method, 'one', 'two')).to be_nil
        expect(clients.map(&:received)).to all(eq(["one\r\ntwo\r\n"]))
      end

      it 'returns nil when a frontend is dead or dies while being written to' do
        dead = client_class.new(alive: false)
        dying = client_class.new(dies_on_write: true)
        RespondReturnSpecSource.clients = [dead, dying]

        expect(output.public_send(method, 'hello')).to be_nil
        expect(dead.received).to be_empty
        expect(dying.received).to eq(["hello\r\n"])
        expect(RespondReturnSpecSource.clients).to be_empty
      end

      it 'returns nil for an Array argument and for no argument' do
        RespondReturnSpecSource.clients = [client_class.new]

        expect(output.public_send(method, %w[a b])).to be_nil
        expect(output.public_send(method)).to be_nil
      end

      it 'returns nil when writing fails and the error is logged' do
        allow($_CLIENT_).to receive(:puts_main_stream).and_raise(IOError, 'closed stream')
        allow(Lich).to receive(:log).and_return(true)

        expect(output.public_send(method, 'hello')).to be_nil
        expect(Lich).to have_received(:log).with(/closed stream/)
      end

      it 'sends the main frontend the text' do
        output.public_send(method, 'hello')

        expect($_CLIENT_).to have_received(:puts_main_stream).with("hello\r\n")
      end
    end
  end

  describe 'Lich::Messaging' do
    let(:messaging) { RespondReturnSpecSource.messaging }
    let(:client) { client_class.new }

    before { RespondReturnSpecSource.clients = [client] }

    it '.msg returns nil and sends the formatted text' do
      expect(messaging.msg('info', 'hello')).to be_nil
      expect(client.received).to eq(["-- hello\r\n"])
    end

    it '.msg returns nil for every preset type' do
      %w[error warn info green link cmd plain].each do |type|
        expect(messaging.msg(type, 'x')).to be_nil
      end
    end

    it '.msg returns nil and sends nothing for a debug message with debug messaging off' do
      expect(messaging.msg('debug', 'hidden')).to be_nil
      expect(client.received).to be_empty
    end

    it '.stream_window returns nil' do
      expect(messaging.stream_window('hello', 'familiar')).to be_nil
      expect(client.received.join).to include('hello')
    end

    it '.mono returns nil' do
      expect(messaging.mono("line one\nline two")).to be_nil
      expect(client.received).to eq(["line one\r\nline two\r\n"])
    end

    # The idiom that broke: the message is a method's last expression and the
    # caller tests the method's result.
    it 'leaves a method that ends in .msg returning nil to its caller' do
      lookup = lambda do |found|
        return :data if found

        messaging.msg('bold', 'Could not find it.')
      end

      expect(lookup.call(true)).to eq(:data)
      expect(lookup.call(false)).to be_nil
      expect(lookup.call(false) || :fallback).to eq(:fallback)
    end
  end
end
