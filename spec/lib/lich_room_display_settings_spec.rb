# frozen_string_literal: true

require_relative '../spec_helper'
require 'rbconfig'
require 'shellwords'

# Direct coverage for the real Lich.display_room_* getters defined in lib/lich.rb.
#
# The main suite mocks Lich with plain attr_accessors (see spec_helper.rb), so the
# game-aware defaulting, the "no game identified yet" state, and DB-backed
# persistence in the real getters are never exercised there. Requiring lib/lich.rb
# into the shared suite is not viable: it also defines Lich.db / Lich.log and
# would override the global mocks other specs depend on. So each case runs the
# real getter in an isolated subprocess with a no-row DB stub (simulating a fresh
# install, which forces the game-aware default path) and a stubbed XMLData.game.
RSpec.describe 'Lich.display_room_* real getters (lib/lich.rb)' do
  # Evaluates a single real getter in a fresh Ruby process and returns its
  # boolean/nil result. Uses the same interpreter running the suite so the
  # subprocess can load lib/lich.rb identically.
  # @param method [Symbol] the Lich getter to invoke
  # @param game [String] the value XMLData.game should report
  # @return [Boolean, nil]
  def real_getter_value(method, game)
    lib_path = File.expand_path('../../lib', __dir__)
    script = <<~RUBY
      $LOAD_PATH.unshift(#{lib_path.inspect})
      require 'lich'
      module XMLData; end
      XMLData.define_singleton_method(:game) { #{game.inspect} }
      def Lich.db
        @stub ||= begin
          o = Object.new
          def o.get_first_value(_query); nil; end
          def o.execute(_query, _params = []); nil; end
          o
        end
      end
      print Lich.#{method}.inspect
    RUBY

    raw = `#{Shellwords.escape(RbConfig.ruby)} -e #{Shellwords.escape(script)}`
    case raw
    when 'true' then true
    when 'false' then false
    when 'nil' then nil
    else raise "unexpected getter output for Lich.#{method} (game=#{game.inspect}): #{raw.inspect}"
    end
  end

  describe '.display_room_mono' do
    it 'defaults on for DragonRealms (the classic roomnumbers.lic mono look)' do
      expect(real_getter_value(:display_room_mono, 'DR')).to be true
    end

    it 'defaults off for GemStone (the proportional game font)' do
      expect(real_getter_value(:display_room_mono, 'GS')).to be false
    end

    it 'stays unresolved (nil) until a game is identified' do
      expect(real_getter_value(:display_room_mono, '')).to be_nil
    end
  end

  describe '.display_room_links' do
    it 'defaults off for DragonRealms (plain text, matching roomnumbers.lic)' do
      expect(real_getter_value(:display_room_links, 'DR')).to be false
    end

    it 'defaults on for GemStone (clickable command links, current core behavior)' do
      expect(real_getter_value(:display_room_links, 'GS')).to be true
    end

    it 'stays unresolved (nil) until a game is identified' do
      expect(real_getter_value(:display_room_links, '')).to be_nil
    end
  end

  # Runs a snippet against the real lib/lich.rb in a fresh subprocess (isolated from the
  # suite's Lich mock) with a stubbed XMLData.game and a single-value lich_settings DB stub,
  # returning the snippet's stdout verbatim. Mirrors real_getter_value but supports the
  # string-valued display_roomid_location getter/setter and a preloaded DB row.
  # @param game [String] the value XMLData.game should report
  # @param body [String] Ruby to execute after setup (expected to print a result)
  # @param db_value [String, nil] the value the settings-table stub returns for any lookup
  # @return [String] the snippet's stdout
  def run_real_lich(game:, body:, db_value: nil)
    lib_path = File.expand_path('../../lib', __dir__)
    script = <<~RUBY
      $LOAD_PATH.unshift(#{lib_path.inspect})
      require 'lich'
      module XMLData; end
      XMLData.define_singleton_method(:game) { #{game.inspect} }
      def Lich.db
        @stub ||= begin
          o = Object.new
          stored = #{db_value.inspect}
          o.define_singleton_method(:get_first_value) { |_query| stored }
          o.define_singleton_method(:execute) { |_query, _params = []| nil }
          o
        end
      end
      #{body}
    RUBY

    `#{Shellwords.escape(RbConfig.ruby)} -e #{Shellwords.escape(script)}`
  end

  describe '.display_roomid_location' do
    it 'defaults to "line" (the historical below-room line) for DragonRealms' do
      expect(run_real_lich(game: 'DR', body: 'print Lich.display_roomid_location.inspect')).to eq('"line"')
    end

    it 'stays unresolved (nil) until a game is identified' do
      expect(run_real_lich(game: '', body: 'print Lich.display_roomid_location.inspect')).to eq('nil')
    end

    it 'returns a valid persisted placement from the settings table' do
      expect(run_real_lich(game: 'DR', db_value: 'title', body: 'print Lich.display_roomid_location.inspect')).to eq('"title"')
    end

    it 'falls back to "line" when the persisted value is not a recognized placement' do
      expect(run_real_lich(game: 'DR', db_value: 'garbage', body: 'print Lich.display_roomid_location.inspect')).to eq('"line"')
    end

    it 'normalizes an assigned value to lowercase' do
      body = 'Lich.display_roomid_location = "TITLE"; print Lich.display_roomid_location.inspect'
      expect(run_real_lich(game: 'DR', body: body)).to eq('"title"')
    end

    it 'ignores an unrecognized assignment and retains the current value' do
      body = 'Lich.display_roomid_location = "both"; Lich.display_roomid_location = "bogus"; print Lich.display_roomid_location.inspect'
      expect(run_real_lich(game: 'DR', body: body)).to eq('"both"')
    end

    it 'accepts each recognized placement value' do
      %w[title line both].each do |placement|
        body = "Lich.display_roomid_location = #{placement.inspect}; print Lich.display_roomid_location.inspect"
        expect(run_real_lich(game: 'DR', body: body)).to eq(placement.inspect)
      end
    end
  end
end
