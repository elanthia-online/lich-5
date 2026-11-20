# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::HeldScripts do
  let(:held) { described_class.new }

  before do
    stub_const('LICH_VERSION', '5.25.1')
    UserVars.held_scripts = nil
    allow(Vars).to receive(:save)
  end

  after { UserVars.held_scripts = nil }

  def remember(outcome: 'held', remote_sha: 'r1', local_sha: 'l1', commit: nil)
    held.remember('scripts', 'foo.lic', remote_sha: remote_sha, local_sha: local_sha, required: '5.26.0', outcome: outcome, commit: commit)
  end

  it 'stores, per repo and script, the remote SHA with the running Lich version and the outcome' do
    remember(outcome: 'installed', commit: 'c' * 40)

    expect(UserVars.held_scripts).to eq(
      'scripts' => {
        'foo.lic' => {
          'remote_sha' => 'r1', 'lich_version' => '5.25.1', 'local_sha' => 'l1',
          'required' => '5.26.0', 'outcome' => 'installed', 'commit' => 'c' * 40
        }
      }
    )
  end

  it 'returns the decision while the remote SHA, the Lich version and the local copy are unchanged' do
    remember

    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: 'l1')).to include('outcome' => 'held', 'required' => '5.26.0')
  end

  it 'drops out when the remote SHA changes' do
    remember

    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r2', local_sha: 'l1')).to be_nil
  end

  it 'drops out when the running Lich version changes' do
    remember
    stub_const('LICH_VERSION', '5.25.2')

    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: 'l1')).to be_nil
  end

  it 'drops out when the local copy changes or is deleted' do
    remember

    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: 'l2')).to be_nil
    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: nil)).to be_nil
  end

  it 'keeps a decision made with no local copy while there still is none' do
    remember(outcome: 'none', local_sha: nil)

    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: nil)).to include('outcome' => 'none')
  end

  it 'keeps decisions apart by repo' do
    remember

    expect(held.lookup('gs-scripts', 'foo.lic', remote_sha: 'r1', local_sha: 'l1')).to be_nil
  end

  it 'ignores stored data that is not a decision' do
    UserVars.held_scripts = { 'scripts' => { 'foo.lic' => 'junk', 'bar.lic' => { 'outcome' => 'other' } } }

    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: 'l1')).to be_nil
    expect(held.lookup('scripts', 'bar.lic', remote_sha: nil, local_sha: nil)).to be_nil

    UserVars.held_scripts = 'junk'
    expect(held.lookup('scripts', 'foo.lic', remote_sha: 'r1', local_sha: 'l1')).to be_nil
  end

  it 'saves once after a change, and not at all when nothing changed' do
    held.save
    expect(Vars).not_to have_received(:save)

    remember
    remember
    held.save
    held.save

    expect(Vars).to have_received(:save).once
  end

  it 'leaves the vars untouched when nothing was ever held' do
    held.forget('scripts', 'foo.lic')
    held.prune('scripts', [])
    held.save

    expect(UserVars.held_scripts).to be_nil
    expect(Vars).not_to have_received(:save)
  end

  it 'forgets one script and saves the removal' do
    remember
    held.save

    held.forget('scripts', 'foo.lic')
    held.save

    expect(UserVars.held_scripts).to eq('scripts' => {})
    expect(Vars).to have_received(:save).twice
  end

  it 'prunes decisions for scripts a sync no longer covers' do
    remember
    held.remember('scripts', 'gone.lic', remote_sha: 'r9', local_sha: nil, required: '5.26.0', outcome: 'none')

    held.prune('scripts', ['foo.lic'])

    expect(UserVars.held_scripts.fetch('scripts').keys).to eq(['foo.lic'])
  end
end
