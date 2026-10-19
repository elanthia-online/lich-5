# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'digest'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'slackbot.rb')

# The shared users cache must be kept per Slack token. UserVars are per
# character, so two characters on the same game instance can hold tokens for
# different workspaces, and a member list (names mapped to user IDs) from one
# workspace is wrong for the other.
#
# Runs the real SlackBot code with real Net::HTTP request objects. Only the
# transport (Net::HTTP#start and #request), SlackBot#sleep and the in-memory
# DB_Store mock from spec_helper stand in for the outside world. Each
# SlackBot.new with a different UserVars.slack_token plays a different
# character sharing the same DB_Store.
RSpec.describe Lich::DragonRealms::SlackBot, 'users cache keyed by token' do
  let(:token_one) { 'xoxb-workspace-one' }
  let(:token_two) { 'xoxb-workspace-two' }

  # The same name has a different user ID in each workspace.
  let(:workspaces) do
    {
      token_one => [{ 'name' => 'alice', 'id' => 'U1ALICE' }],
      token_two => [{ 'name' => 'alice', 'id' => 'U2ALICE' }, { 'name' => 'bob', 'id' => 'U2BOB' }]
    }
  end

  let(:users_list_calls) { [] }
  let(:posted) { [] }
  let(:messages) { [] }
  let(:throttled_tokens) { [] }
  let(:clock) { { offset: 0.0 } }
  # Runs inside a users.list request, before the reply, when set.
  let(:during_users_list) { { hook: nil } }

  def http_response(code, body = '', headers = {})
    res = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s).new('1.1', code.to_s, 'msg')
    headers.each { |k, v| res[k] = v }
    res.instance_variable_set(:@body, body)
    res.instance_variable_set(:@read, true)
    res
  end

  def ok(body = {})
    http_response(200, body.merge('ok' => true).to_json)
  end

  def cache_key(token)
    "_slackbot_users_cache:#{Digest::SHA256.hexdigest(token)}"
  end

  def cached_list(token)
    Lich::Common::DB_Store.get_data('DR', cache_key(token))['members']
  end

  # A character logging in with the given token.
  def character_with(token)
    UserVars.slack_token = token
    described_class.new
  end

  before do
    allow(XMLData).to receive(:game).and_return('DR')
    allow(Lich).to receive(:log)
    allow(Lich::Messaging).to receive(:msg) { |_type, text| messages << text }

    allow_any_instance_of(Net::HTTP).to receive(:start) { |http| http }
    allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
      method = req.path.sub('/api/', '')
      params = URI.decode_www_form(req.body).to_h
      token = params['token']
      case method
      when 'auth.test'
        raise "unplanned token in auth.test: #{token.inspect}" unless workspaces.key?(token)

        ok
      when 'users.list'
        users_list_calls << token
        during_users_list[:hook]&.call
        next http_response(429, '', 'Retry-After' => '1') if throttled_tokens.include?(token)

        ok('members' => workspaces.fetch(token))
      when 'chat.postMessage'
        posted << params
        ok('ts' => '1')
      else
        raise "unplanned call to #{method}"
      end
    end

    allow(Process).to receive(:clock_gettime).and_wrap_original do |original, id, *rest|
      value = original.call(id, *rest)
      id == Process::CLOCK_MONOTONIC && rest.empty? ? value + clock[:offset] : value
    end
    allow_any_instance_of(described_class).to receive(:sleep) { |_bot, seconds| clock[:offset] += seconds }
  end

  after do
    UserVars.slack_token = nil
  end

  describe 'characters with tokens for different workspaces' do
    it "fetches its own workspace's list instead of reading the other workspace's cache" do
      character_with(token_one)
      second = character_with(token_two)

      expect(users_list_calls).to eq([token_one, token_two])
      expect(second).to be_initialized
    end

    it "sends to the user ID from its own workspace, not the other workspace's" do
      character_with(token_one)
      second = character_with(token_two)

      second.direct_message('alice', 'hello')

      expect(posted.map { |p| [p['token'], p['channel']] }).to eq([[token_two, 'U2ALICE']])
    end

    it "never adds a user from another token's cache when it reloads for an unknown user" do
      first = character_with(token_one)
      # The first cache entry expires, so the second character fetches its
      # own list and caches bob, who exists only in workspace two.
      Lich::Common::DB_Store.reset!
      character_with(token_two)
      expect(users_list_calls).to eq([token_one, token_two])

      UserVars.slack_token = token_one
      result = first.direct_message('bob', 'hello')

      expect(result).to be_nil
      expect(posted).to be_empty
      expect(messages).to include(a_string_including("user 'bob' not found"))
    end

    it "does not fall back to another token's cache while its users.list is throttled" do
      character_with(token_one)
      throttled_tokens << token_two
      second = character_with(token_two)

      expect(second).not_to be_initialized
      expect(second.direct_message('alice', 'hello')).to be_nil
      expect(posted).to be_empty
    end

    it "keeps each token's cache when the other token's list is written" do
      character_with(token_one)
      character_with(token_two)
      users_list_calls.clear

      third = character_with(token_one)
      third.direct_message('alice', 'hello')

      expect(users_list_calls).to be_empty
      expect(posted.map { |p| p['channel'] }).to eq(['U1ALICE'])
      expect(cached_list(token_one)).to eq(workspaces[token_one])
      expect(cached_list(token_two)).to eq(workspaces[token_two])
    end
  end

  describe 'characters with the same token' do
    it 'share one cached list, so only the first one calls users.list' do
      character_with(token_one)
      second = character_with(token_one)

      second.direct_message('alice', 'hello')

      expect(users_list_calls).to eq([token_one])
      expect(posted.map { |p| p['channel'] }).to eq(['U1ALICE'])
    end
  end

  describe 'cache entry' do
    it 'is stored under a digest of the token, never the token itself' do
      character_with(token_one)

      store = Lich::Common::DB_Store.instance_variable_get(:@store)
      expect(store.keys).to include(a_string_ending_with(cache_key(token_one)))
      expect(store.keys.join("\n")).not_to include(token_one)
      expect(store.values.to_s).not_to include(token_one)
    end

    it 'goes under the token that made the users.list call even if the token changes during it' do
      UserVars.slack_token = token_one
      during_users_list[:hook] = -> { UserVars.slack_token = token_two }
      described_class.new

      expect(cached_list(token_one)).to eq(workspaces[token_one])
      expect(Lich::Common::DB_Store.get_data('DR', cache_key(token_two))).to be_empty
    end

    it 'is read under the token that made the users.list call when throttled, even if the token changes during the wait' do
      # Workspace two has a fresh cache entry.
      character_with(token_two)
      users_list_calls.clear

      # Workspace one's users.list is throttled. During the throttle wait
      # (after the first users.list call, not the startup jitter) the
      # character's token changes to workspace two's.
      throttled_tokens << token_one
      UserVars.slack_token = token_one
      allow_any_instance_of(described_class).to receive(:sleep) do |_bot, seconds|
        clock[:offset] += seconds
        UserVars.slack_token = token_two unless users_list_calls.empty?
      end
      bot = described_class.new

      expect(users_list_calls).not_to be_empty
      expect(users_list_calls).to all(eq(token_one))
      expect(bot).not_to be_initialized
      expect(Lich).not_to have_received(:log).with(a_string_including('Throttled, but'))
    end

    it 'written by an earlier Lich under the old shared key is ignored' do
      Lich::Common::DB_Store.store_data(
        'DR', '_slackbot_users_cache',
        { 'members' => [{ 'name' => 'alice', 'id' => 'ULEGACY' }], 'fetched_at' => Time.now.to_i }
      )

      bot = character_with(token_one)
      bot.direct_message('alice', 'hello')

      expect(users_list_calls).to eq([token_one])
      expect(posted.map { |p| p['channel'] }).to eq(['U1ALICE'])
    end
  end

  describe 'without a token' do
    let(:bot) { character_with(token_one) }
    let(:members) { [{ 'name' => 'carol', 'id' => 'U3' }] }

    [nil, ''].each do |missing|
      it "reads no cache for #{missing.inspect}" do
        bot.send(:write_users_cache, members, token_one)
        # A fresh row at the key an unguarded lookup of "" would use, so the
        # read returns nil only because the guard skips it.
        Lich::Common::DB_Store.store_data(
          'DR', cache_key(''), { 'members' => members, 'fetched_at' => Time.now.to_i }
        )

        expect(bot.send(:read_users_cache, missing)).to be_nil
        expect(bot.send(:cached_members, missing)).to be_nil
      end

      it "writes no cache for #{missing.inspect}" do
        bot
        before_write = Lich::Common::DB_Store.instance_variable_get(:@store).dup

        bot.send(:write_users_cache, members, missing)

        expect(Lich::Common::DB_Store.instance_variable_get(:@store)).to eq(before_write)
      end
    end

    it 'defaults to the current UserVars.slack_token' do
      bot.send(:write_users_cache, members)
      expect(cached_list(token_one)).to eq(members)

      UserVars.slack_token = nil
      expect(bot.send(:read_users_cache)).to be_nil
    end
  end
end
