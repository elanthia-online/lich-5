# frozen_string_literal: true

require_relative '../spec_helper'

# spec/fixtures/streams/MANIFEST.md records where each replay fixture came from.
# `*.md` is gitignored repo-wide, so the manifest needs its own re-include; this
# fails if it goes missing from a checkout or a fixture is added without a row.
RSpec.describe 'stream replay fixture manifest' do
  streams = File.expand_path('../fixtures/streams', __dir__)
  manifest = File.join(streams, 'MANIFEST.md')

  it 'exists' do
    expect(File).to exist(manifest)
  end

  it 'lists every fixture' do
    text = File.exist?(manifest) ? File.read(manifest) : ''
    missing = Dir[File.join(streams, '*.xml')].map { |f| File.basename(f) }.reject { |f| text.include?("`#{f}`") }
    expect(missing).to be_empty, "not in MANIFEST.md: #{missing.join(', ')}"
  end
end
