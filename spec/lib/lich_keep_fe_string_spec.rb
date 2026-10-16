# frozen_string_literal: true

require_relative '../spec_helper'
require 'rbconfig'
require 'shellwords'

# The real Lich.keep_fe_string getter/setter from lib/lich.rb. The suite mocks
# Lich, so (as in lich_room_display_settings_spec.rb) each case loads the real
# lib/lich.rb in a fresh Ruby process with a stubbed lich_settings DB.
RSpec.describe 'Lich.keep_fe_string (lib/lich.rb)' do
  # @param body [String] Ruby to run after setup; prints the result
  # @param db_value [String, nil] what the settings lookup returns
  # @param db_error [Boolean] make the settings lookup raise
  # @return [String] the snippet's stdout
  def run_real_lich(body:, db_value: nil, db_error: false)
    lib_path = File.expand_path('../../lib', __dir__)
    script = <<~RUBY
      $LOAD_PATH.unshift(#{lib_path.inspect})
      require 'lich'
      def Lich.log(msg) = (@logged ||= []) << msg
      def Lich.logged = @logged.to_a
      def Lich.db
        @stub ||= begin
          o = Object.new
          stored = #{db_value.inspect}
          fail_read = #{db_error}
          o.define_singleton_method(:get_first_value) { |_query| fail_read ? raise(IOError, 'disk gone') : stored }
          o.define_singleton_method(:executed) { @executed ||= [] }
          o.define_singleton_method(:execute) { |query, params = []| executed << [query, params] }
          o
        end
      end
      #{body}
    RUBY

    `#{Shellwords.escape(RbConfig.ruby)} -e #{Shellwords.escape(script)}`
  end

  it 'defaults to false (replace the client string) when nothing is saved' do
    expect(run_real_lich(body: 'print Lich.keep_fe_string.inspect')).to eq('false')
  end

  it 'reads a saved true/on/yes as true' do
    %w[true on yes TRUE].each do |saved|
      expect(run_real_lich(db_value: saved, body: 'print Lich.keep_fe_string.inspect')).to eq('true'), saved
    end
  end

  it 'reads anything else as false, including words that contain "on"' do
    %w[false off none nonsense].each do |saved|
      expect(run_real_lich(db_value: saved, body: 'print Lich.keep_fe_string.inspect')).to eq('false'), saved
    end
  end

  it 'persists an assignment and returns it' do
    body = 'Lich.keep_fe_string = true; print [Lich.keep_fe_string, Lich.db.executed.last.last].inspect'
    expect(run_real_lich(body: body)).to eq('[true, ["true"]]')
  end

  it 'answers false and logs when the settings read fails, so the login handshake goes on' do
    body = 'print [Lich.keep_fe_string, Lich.logged.first.to_s.start_with?("warning: could not read keep_fe_string")].inspect'
    expect(run_real_lich(db_error: true, body: body)).to eq('[false, true]')
  end
end
