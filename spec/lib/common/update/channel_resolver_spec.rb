# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::ChannelResolver do
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { described_class.new(client) }

  describe '#major_minor_patch_from' do
    it 'returns [nil, nil, nil] for non-version strings' do
      expect(resolver.major_minor_patch_from('not-a-version')).to eq([nil, nil, nil])
      expect(resolver.major_minor_patch_from('')).to eq([nil, nil, nil])
      expect(resolver.major_minor_patch_from(nil)).to eq([nil, nil, nil])
    end

    it 'parses version from branch names like pre/beta/5.15.3' do
      expect(resolver.major_minor_patch_from('pre/beta/5.15.3')).to eq([5, 15, 3])
    end

    it 'parses two-part version as patch=0' do
      expect(resolver.major_minor_patch_from('v5.14')).to eq([5, 14, 0])
    end
  end

  describe '#version_key' do
    it 'sorts beta.10 after beta.9' do
      v9 = resolver.version_key('5.15.0-beta.9')
      v10 = resolver.version_key('5.15.0-beta.10')

      expect(v10).to be > v9
    end

    it 'sorts release after beta' do
      release = resolver.version_key('5.15.0')
      beta = resolver.version_key('5.15.0-beta.1')

      expect(release).to be > beta
    end
  end

  describe '#resolve_channel_ref' do
    it 'returns STABLE_REF for unknown channels' do
      expect(resolver.resolve_channel_ref(:unknown)).to eq('main')
    end
  end
end
