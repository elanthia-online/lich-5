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
end
