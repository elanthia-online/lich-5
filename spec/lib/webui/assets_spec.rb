# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'WebUI browser assets' do
  let(:assets_dir) { Lich::WebUI::Service::ASSETS_DIR }
  let(:html) { File.read(File.join(assets_dir, 'index.html')) }
  let(:script_tags) { html.scan(/<script\b[^>]*>/i) }
  let(:loaded_scripts) { script_tags.filter_map { |tag| tag[%r{\ssrc="/assets/([a-z_]+\.js)"}, 1] } }
  let(:shipped_scripts) { Dir.children(assets_dir).grep(/\.js\z/).sort }
  # Every shipped script is scanned, whether or not index.html loads it.
  let(:javascript) { shipped_scripts.map { |name| File.read(File.join(assets_dir, name)) }.join("\n") }

  it 'loads exactly the shipped scripts, each as an external file, so the guard below sees all browser code' do
    expect(shipped_scripts).not_to be_empty
    expect(loaded_scripts.length).to eq(script_tags.length), 'every <script> tag must load a named asset file'
    expect(loaded_scripts.sort).to eq(shipped_scripts)
    expect(html).not_to match(%r{<script\b[^>]*>[^<]+</script>}i)
    expect(html).not_to match(/\son[a-z]+\s*=/i)
  end

  # A regression aid for common string-to-markup and string-to-code sinks; it is
  # not a proof that no other DOM sink exists. Behavioral hostile-text tests remain.
  it 'constructs hostile text as text nodes without string-built DOM or evaluation sinks', security_id: 'sec-escaping' do
    sinks = {
      'innerHTML/outerHTML'      => /\b(?:inner|outer)HTML\b/,
      'insertAdjacentHTML'       => /insertAdjacentHTML/,
      'document.write'           => /document\.write/,
      'eval'                     => /\beval\s*\(/,
      'Function constructor'     => /\bFunction\s*\(/,
      'string timer'             => /set(?:Timeout|Interval)\s*\(\s*["'`]/,
      'createContextualFragment' => /createContextualFragment/,
      'DOMParser'                => /DOMParser/,
      'srcdoc'                   => /\bsrcdoc\b/,
      'javascript: URL'          => /javascript:/i,
      'event-handler attribute'  => /setAttribute\(\s*["'`]on/i
    }
    found = sinks.select { |_name, pattern| javascript.match?(pattern) }.keys
    expect(found).to be_empty, "string-built DOM or evaluation sinks found: #{found.join(', ')}"
    expect(javascript).to include('textContent', 'document.createElement')
  end

  it 'announces only targeted status updates and focuses controls or their wrappers' do
    expect(html).to include('<main id="pages"></main>')
    expect(html).not_to match(/<main id="pages"[^>]*aria-live/)
    expect(javascript).to include('focusRoot?.matches("input, select, button, textarea")')
  end
end
