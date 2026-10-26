# frozen_string_literal: true

require 'json'
require 'prism'
require 'digest'
require 'open3'

# Offline evidence builder for the cached 33-script cohort, not a script runner.
# Reads only pinned Git blobs, checks the audit hashes, and decodes selected Prism
# string nodes. Interpolation is substituted as data; no source Ruby is evaluated.
# Usage: ruby spec/support/build_css_decoration_corpus.rb EO_REPO MIRROR_REPO > fixture.json
module CssDecorationCorpus
  LINES = {
    'Combatical' => [2343], 'UberBarWiz' => [553, 562, 571, 580, 589, 598, 607, 616, 625, 634, 643],
    'as_audit' => [2246], 'bug-catcher' => [168], 'calibrate_creaturebar' => [449],
    'creaturebar' => [801], 'creaturewindow' => [1005], 'exitwindow' => [564],
    'gemstone-tracker' => [1094], 'gemstonev' => [90, 171, 177, 625, 718],
    'generate-gemstone' => [373], 'grids' => [1719, 1733, 1739, 1746, 1762, 1773, 1866, 1932, 1956, 1982, 2339, 2380],
    'grinsawl' => [], 'gshunting4all' => [2305], 'hazardwindow' => [209], 'jastev' => [73, 82],
    'manatimer' => [87, 88, 93], 'manatimer-gtk3' => [58], 'merchantical' => [189],
    'mission-gemstone' => [631], 'nautical-charts' => [382], 'panelcontrol' => [565],
    'playerwindow' => [501], 'rafflewindow' => [554], 'spellson' => [117], 'staminabar2' => [34],
    'stormsync' => [3573, 3575], 'test-tpick' => [564, 952], 'thunder' => [992],
    'timers' => [379, 395, 432, 444], 'tpick' => [95, 2558], 'tpick2' => [862, 1253], 'treasurewindow' => [211],
  }.freeze
  METHODS = %i[load load_from_data add_provider remove_provider add_provider_for_screen remove_provider_for_screen add_class remove_class has_class? list_classes].freeze
  # Reviewed CSS-only source slices. Dependencies are explicitly rebound in specs.
  EXCERPTS = {
    'tpick' => [[94, 291], [2557, 2564], [2939, 2939], [2084, 2084]],
    'manatimer' => [[83, 94], [76, 76]], 'staminabar2' => [[32, 37]], 'spellson' => [[116, 120]],
    'as_audit' => [[2245, 2259]], 'panelcontrol' => [[565, 644]],
    'Combatical' => [[2342, 2447], [2192, 2192], [2127, 2127]],
    'grinsawl' => [[2491, 2499]], 'stormsync' => [[3572, 3579]],
    'timers' => [[378, 390], [392, 392], [410, 410]],
    'grids' => [[1731, 1781]],
  }.freeze

  def self.walk(node)
    [node] + node.compact_child_nodes.flat_map { |child| walk(child) }
  end

  # Diagnostic substitutions are intentionally fixed, never user settings/defaults.
  def self.substitute(expression)
    case expression
    when "\#{w}" then 'window#merchantical_win' # Literal selector at merchantical:183.
    when "\#{ts}", "\#{bts}", "\#{chk}" then '' # Optional shadow/check rules disabled in this sample.
    when /[Ss]ize|[Hh]eight|[Ww]idth|[Pp]osition|[Dd]egrees|scale/ then '12'
    when /css_name/ then 'button'
    when /Image Location/ then 'omitted.png'
    when /Radial Shape/ then 'circle'
    when /\#\{colors\}/ then '#112233, #445566'
    else '#112233'
    end
  end

  def self.string_at(nodes, line)
    nodes.find { |node| (node.is_a?(Prism::StringNode) || node.is_a?(Prism::InterpolatedStringNode)) && node.location.start_line == line } || raise("No string at #{line}")
  end

  def self.render(node, replacements, used)
    return node.unescaped if node.is_a?(Prism::StringNode)
    return node.parts.map { |part| render(part, replacements, used) }.join if node.is_a?(Prism::InterpolatedStringNode)

    expression = node.location.slice
    value = replacements.fetch(expression) { substitute(expression) }
    used[expression] = value
    value
  end

  def self.sample(nodes, line, replacements = {})
    node = string_at(nodes, line)
    used = {}
    css = render(node, replacements, used)
    last = node.respond_to?(:closing_loc) ? node.closing_loc&.end_line : nil
    { 'lines' => [line, last || node.location.end_line], 'kind' => used.empty? ? 'literal' : 'interpolation sample',
      'substitutions' => used, 'css' => css }
  end

  def self.composite(nodes, pieces, note, separator = '')
    samples = pieces.map { |line, replacements| sample(nodes, line, replacements || {}) }
    { 'lines' => samples.map { |s| s['lines'] }, 'kind' => 'assembly sample', 'assembly' => note,
      'substitutions' => samples.map { |s| s['substitutions'] }, 'css' => samples.map { |s| s['css'] }.join(separator) }
  end

  def self.samples(name, nodes)
    replacements = name == 'manatimer' ? { "\#{_bar_base}" => sample(nodes, 86)['css'] } : {}
    result = LINES.fetch(name).map { |line| sample(nodes, line, replacements) }
    if %w[spellson manatimer-gtk3].include?(name)
      result.first['css'] = format(result.first['css'], 'powderblue')
      result.first['kind'] = 'format sample'
      result.first['substitutions'] = { '@circle_color' => 'powderblue' }
    elsif name == 'grinsawl'
      pieces = [[2491]] + { 'gold' => '#d4af37', 'silver' => '#c0c0c0', 'bronze' => '#cd7f32', 'none' => '#888888', 'empty' => '#555555' }.map do |key, color|
        [2495, { "\#{k}" => key, "\#{c}" => color, "\#{style}" => key == 'empty' ? 'dashed' : 'solid' }]
      end
      result << composite(nodes, pieces, 'All five literal tiers from lines 2418 and 2492-2496; no runtime inputs.')
    elsif name == 'stormsync'
      constant = nodes.find { |node| node.is_a?(Prism::ConstantWriteNode) && node.name == :DEFAULT_COLORS }
      colors = constant.value.elements.map(&:unescaped)
      pieces = [[3311], [3312], [3314]] + colors.each_with_index.map { |color, index| [3316, { "\#{color}" => color, "\#{ix}" => index.to_s }] }
      result << composite(nodes, pieces, "update_colors using #{colors.length} source DEFAULT_COLORS; saved settings may replace this list.")
      result << composite(nodes, [[3757], [3762], [3766]], 'Editor with both foreground/background present; sampled color strings.', "\n")
      pieces = [[4735]] + 2.times.flat_map { |index| [[4747, { "\#{ix}" => index.to_s }], [4751, { "\#{ix}" => index.to_s }]] }
      result << composite(nodes, pieces, 'Duplicate merge with two targets and both colors present; sampled color strings.')
    end
    result.each do |entry|
      entry['characters'] = entry['css'].length
      entry['bytes'] = entry['css'].bytesize
      entry['sha256'] = Digest::SHA256.hexdigest(entry['css'])
    end
    result
  end

  def self.calls(nodes)
    nodes.filter_map do |node|
      next unless node.is_a?(Prism::CallNode) && METHODS.include?(node.name)
      arguments = node.arguments&.arguments || []
      if node.name == :load
        next unless arguments.any? { |arg| arg.is_a?(Prism::KeywordHashNode) && arg.elements.any? { |pair| pair.is_a?(Prism::AssocNode) && pair.key.is_a?(Prism::SymbolNode) && pair.key.unescaped == 'data' } }
      end
      { 'line' => node.location.start_line, 'method' => node.name.to_s, 'source' => node.location.slice,
        'arguments' => arguments.map { |arg| arg.location.slice } }
    end.sort_by { |call| call['line'] }
  end

  def self.build(eo_repo, mirror_repo)
    audit_path = File.expand_path('../fixtures/webui/css-provenance.json', __dir__)
    audit = JSON.parse(File.read(audit_path))
    records = audit.fetch('whole_corpus_provider_references').map do |record|
      eo = record.fetch('source').start_with?('eo')
      revision = audit.fetch('focused_audit').fetch('baselines').fetch(eo ? 'eo-originals' : 'mirror')
      path = "#{eo ? 'scripts' : 'lib'}/#{record.fetch('name')}.lic"
      source, error, status = Open3.capture3('git', '-C', eo ? eo_repo : mirror_repo, 'show', "#{revision}:#{path}")
      raise "Cannot read #{path}: #{error}" unless status.success?
      raise "Source hash mismatch: #{path}" unless Digest::SHA256.hexdigest(source) == record.fetch('sha256')
      parsed = Prism.parse(source)
      raise "Parse error: #{path}" unless parsed.success?
      nodes = walk(parsed.value)
      payloads = samples(record.fetch('name'), nodes)
      source_calls = calls(nodes)
      payloads.each do |payload|
        start_line = payload.fetch('lines').flatten.min
        loader = source_calls.find { |call| %w[load load_from_data].include?(call['method']) && call['line'] >= start_line }
        raise "Missing loader for #{path}:#{start_line}" unless loader
        payload['loader_line'] = loader['line']
        payload['loader_method'] = loader['method']
      end
      excerpts = EXCERPTS.fetch(record.fetch('name'), []).map do |first, last|
        text = source.lines[(first - 1)..(last - 1)].join
        { 'line' => first, 'end_line' => last, 'source' => text, 'sha256' => Digest::SHA256.hexdigest(text) }
      end
      { 'name' => record.fetch('name'), 'source' => record.fetch('source'), 'revision' => revision, 'path' => path,
        'source_sha256' => record.fetch('sha256'), 'remaining_exposure' => !record['converted'] && record['name'] != 'spellson',
        'calls' => source_calls, 'samples' => payloads, 'excerpts' => excerpts,
        'max_measured_characters' => payloads.map { |s| s['characters'] }.max,
        'runtime_maximum_proven' => payloads.all? { |s| s['kind'] == 'literal' },
        'whole_setup_rendered' => false,
        'next_non_css_blocker' => case record.fetch('name')
                                  when 'tpick' then 'HeaderBar at line 2084: confirmed independent blocker, not a full-setup first-failure claim.'
                                  when 'manatimer' then 'Gdk::Display at line 76 precedes CSS: confirmed independent blocker.'
                                  else 'Not determined: CSS excerpts only.'
                                  end }
    end
    { 'description' => 'Pinned source CSS evidence. No original script executed. Dynamic samples are not runtime maxima.',
      'audit_sha256' => Digest::SHA256.file(audit_path).hexdigest, 'bound' => 8192, 'scripts' => records }
  end
end

puts JSON.pretty_generate(CssDecorationCorpus.build(ARGV.fetch(0), ARGV.fetch(1))) if $PROGRAM_NAME == __FILE__
