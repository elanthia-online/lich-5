# frozen_string_literal: true

require 'json'

module StreamReplay
  # Delta-encoded golden snapshots.
  #
  # A replay yields one full snapshot per prompt. Storing those verbatim would be
  # huge and unreadable, so a golden stores, per prompt, only the fields whose
  # value changed since the previous prompt. Fields are addressed by path: the
  # sections listed in SPLIT are split one level down ("xmldata.room_title",
  # "drroom.pcs"); other top-level keys ("dr_creatures", "stripped") are whole.
  #
  # One JSON object per line: {"prompt":N,"changes":{path=>value}}. Prompts with
  # no changes are omitted, so a golden diff points straight at the prompt and
  # field that moved.
  module Golden
    SPLIT = %w[xmldata gameobj drroom drspells].freeze
    VOLATILE = %w[prompt].freeze

    module_function

    def flatten(snapshot)
      snapshot.each_with_object({}) do |(key, value), out|
        next if VOLATILE.include?(key)

        if SPLIT.include?(key) && value.is_a?(Hash) && !value.key?('error')
          value.each { |k, v| out["#{key}.#{k}"] = v }
        else
          out[key] = value
        end
      end
    end

    # @param snapshots [Array<Hash>] full per-prompt snapshots, in order
    # @return [Array<Hash>] delta records
    def encode(snapshots)
      previous = {}
      snapshots.each_with_index.filter_map do |snap, i|
        flat = flatten(snap)
        changes = flat.reject { |path, value| previous.key?(path) && previous[path] == value }
        (previous.keys - flat.keys).each { |gone| changes[gone] = nil }
        previous = flat
        { 'prompt' => i + 1, 'changes' => changes.sort.to_h } unless changes.empty?
      end
    end

    def write(path, deltas)
      File.write(path, deltas.map { |d| JSON.generate(d) }.join("\n") + "\n")
    end

    def read(path)
      File.readlines(path, chomp: true).reject(&:empty?).map { |l| JSON.parse(l) }
    end

    # @return [Array<String>] human-readable mismatches, at most +limit+
    def diff(expected, actual, limit: 20)
      exp = expected.to_h { |d| [d['prompt'], d['changes']] }
      act = actual.to_h { |d| [d['prompt'], d['changes']] }
      out = []
      (exp.keys | act.keys).sort.each do |prompt|
        e = exp[prompt] || {}
        a = act[prompt] || {}
        (e.keys | a.keys).sort.each do |path|
          next if e.key?(path) == a.key?(path) && e[path] == a[path]

          out << "prompt #{prompt} #{path}:\n    expected #{e.key?(path) ? JSON.generate(e[path])[0, 300] : '(unchanged)'}\n    actual   #{a.key?(path) ? JSON.generate(a[path])[0, 300] : '(unchanged)'}"
          return out if out.length >= limit
        end
      end
      out
    end
  end
end
