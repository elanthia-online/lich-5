# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/submission'

RSpec.describe Lich::WebUI::Submission do
  let(:secret) { Lich::WebUI::SensitiveValue.viewer('canary-submission-3b8f') }
  let(:submission) do
    described_class.new(viewer_id: 'viewer-1', values: { 'page:p/text_input:name' => 'Ada', 'page:p/password_input:pw' => secret })
  end

  it 'fetches values by string ID and lists IDs in submission order' do
    expect(submission['page:p/text_input:name']).to eq('Ada')
    expect(submission.fetch(:'page:p/text_input:name')).to eq('Ada')
    expect(submission.cids).to eq(%w[page:p/text_input:name page:p/password_input:pw])
    expect(submission.fetch('absent') { |missing| "no #{missing}" }).to eq('no absent')
    expect { submission['absent'] }.to raise_error(KeyError)
  end

  it 'reports sensitive carriers and disposes any that remain unused' do
    expect(submission.sensitive_cids).to eq(%w[page:p/password_input:pw])

    submission.discard_sensitive!
    expect(secret).to be_consumed
  end

  it 'hands the snapshot to one commit block and refuses a second commit' do
    expect(submission.commit { |values| values.keys.length }).to eq(2)
    expect { submission.commit { nil } }.to raise_error(Lich::WebUI::Error, /already been committed/)
    expect { described_class.new(viewer_id: 'v', values: {}).commit }.to raise_error(ArgumentError, /requires a block/)
  end
end
