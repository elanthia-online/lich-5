# frozen_string_literal: true

# Adversarial checks against the real lib/gemstone/creatures/*.rb data, not
# fixtures - designed to catch corrupt data, silently-dropped unknown
# fields, and lookup-key collisions that only show up at real scale. Several
# of these were written specifically because they caught a real problem
# during a first bulk data import (see git history around this file).

require_relative '../../spec_helper'
require 'gemstone/creature'

RSpec.describe 'lib/gemstone/creatures data integrity' do
  def creatures_dir
    File.join(__dir__, '..', '..', '..', 'lib', 'gemstone', 'creatures')
  end

  # Every key CreatureTemplate#initialize actually reads. A key outside this
  # list is silently ignored by CreatureTemplate.new - no error, the data
  # just vanishes - so a typo (:mx_hp) or a scraper/tool adding a field
  # nobody's wired up yet would never surface without this check.
  def known_top_level_keys
    %i[
      schema_version name noun url picture level family type undead
      blood bones limbs witherable sympathy muggable sleepable boss boss_type otherclass bcs max_hp speed height
      size areas attack_attributes defense_attributes special_other
      abilities alchemy abilities_misc equipment treasure messaging
    ]
  end

  def defense_numeric_fields
    %i[
      melee ranged bolt udf bar_td cle_td emp_td pal_td ran_td sor_td
      wiz_td mje_td mne_td mjs_td mns_td mnm_td
    ]
  end

  def creature_files
    Dir.glob(File.join(creatures_dir, '*.rb')).reject { |p| File.basename(p) == '_creature_template.rb' }
  end

  def load_data(path)
    eval(File.read(path), binding, path, 1)
  end

  def lookup_key_for(path, data)
    fallback_name = File.basename(path, '.rb').tr('_', ' ')
    name = data[:name].to_s.strip.empty? ? fallback_name : data[:name]
    Lich::Gemstone::CreatureTemplate.fix_template_name(name)
  end

  it 'has creature files to check (guards against an empty/misconfigured directory silently passing everything)' do
    expect(creature_files.size).to be > 0
  end

  it 'every file evals to a Hash' do
    offenders = creature_files.reject { |p| load_data(p).is_a?(Hash) }

    expect(offenders.map { |p| File.basename(p) }).to be_empty
  end

  it 'has no unexpected top-level keys' do
    offenders = {}
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      extra = data.keys - known_top_level_keys
      offenders[File.basename(path)] = extra unless extra.empty?
    end

    expect(offenders).to be_empty
  end

  it 'areas entries are well-formed: String name, uids an Array of ascending Integer Ranges' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      areas = data[:areas]
      next if areas.nil?

      unless areas.is_a?(Array)
        offenders << "#{File.basename(path)}: areas is #{areas.class}"
        next
      end
      areas.each do |a|
        ok = a.is_a?(Hash) &&
             a[:name].is_a?(String) && !a[:name].strip.empty? &&
             a[:uids].is_a?(Array) &&
             a[:uids].all? { |r| r.is_a?(Range) && r.first.is_a?(Integer) && r.last.is_a?(Integer) && r.first <= r.last }
        offenders << "#{File.basename(path)}: #{a.inspect[0, 80]}" unless ok
      end
    end

    expect(offenders).to be_empty
  end

  it 'level and max_hp are Integer or nil, never a stray string like "170+"' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      %i[level max_hp].each do |field|
        value = data[field]
        offenders << "#{File.basename(path)} #{field}=#{value.inspect}" if value && !value.is_a?(Integer)
      end
    end

    expect(offenders).to be_empty
  end

  it 'otherclass/areas/otherclass-bearing containers are the expected container types' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      offenders << "#{File.basename(path)} otherclass" unless data[:otherclass].nil? || data[:otherclass].is_a?(Array)
      offenders << "#{File.basename(path)} areas" unless data[:areas].nil? || data[:areas].is_a?(Array)
      offenders << "#{File.basename(path)} attack_attributes" unless data[:attack_attributes].nil? || data[:attack_attributes].is_a?(Hash)
      offenders << "#{File.basename(path)} defense_attributes" unless data[:defense_attributes].nil? || data[:defense_attributes].is_a?(Hash)
      offenders << "#{File.basename(path)} treasure" unless data[:treasure].nil? || data[:treasure].is_a?(Hash)
      offenders << "#{File.basename(path)} messaging" unless data[:messaging].nil? || data[:messaging].is_a?(Hash)
    end

    expect(offenders).to be_empty
  end

  it 'no defense Range has its bounds reversed' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      def_ = data[:defense_attributes] || {}
      defense_numeric_fields.each do |field|
        value = def_[field]
        offenders << "#{File.basename(path)} #{field}=#{value.inspect}" if value.is_a?(Range) && value.first > value.last
      end
    end

    expect(offenders).to be_empty
  end

  it 'probe facts and muggable are only true, false, or nil - never coerced or stringly-typed' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      %i[blood bones limbs witherable sympathy muggable sleepable].each do |field|
        value = data[field]
        offenders << "#{File.basename(path)} #{field}=#{value.inspect}" unless value.nil? || value == true || value == false
      end
    end

    expect(offenders).to be_empty
  end

  it 'speed is Integer seconds, an ascending Range, or nil - never a wiki string' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      value = data[:speed]
      ok = value.nil? || value.is_a?(Integer) ||
           (value.is_a?(Range) && value.first.is_a?(Integer) && value.first <= value.last)
      offenders << "#{File.basename(path)} speed=#{value.inspect}" unless ok
    end

    expect(offenders).to be_empty
  end

  it 'defense numbers (max_hp, melee/ranged/bolt/udf, every TD) are Integer, ascending Range, or nil - never a wiki string' do
    numeric_keys = %i[melee ranged bolt udf bar_td cle_td emp_td pal_td ran_td sor_td wiz_td
                      mje_td mne_td mjs_td mns_td mnm_td]
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      values = { max_hp: data[:max_hp] }
      numeric_keys.each { |k| values[k] = data.dig(:defense_attributes, k) }
      values.each do |key, value|
        ok = value.nil? || value.is_a?(Integer) ||
             (value.is_a?(Range) && value.first.is_a?(Integer) && value.first <= value.last)
        offenders << "#{File.basename(path)} #{key}=#{value.inspect}" unless ok
      end
    end

    expect(offenders).to be_empty
  end

  it 'boss_type is nil, "pack", "miniboss", or "boss" - never a typo or a bare symbol' do
    offenders = []
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      value = data[:boss_type]
      offenders << "#{File.basename(path)} boss_type=#{value.inspect}" unless value.nil? || %w[pack miniboss boss].include?(value)
    end

    expect(offenders).to be_empty
  end

  it 'no two files collide on the same CreatureTemplate lookup key' do
    seen = Hash.new { |h, k| h[k] = [] }
    creature_files.each do |path|
      data = load_data(path)
      next unless data.is_a?(Hash)

      seen[lookup_key_for(path, data)] << File.basename(path)
    end

    collisions = seen.select { |_key, files| files.size > 1 }

    expect(collisions).to be_empty
  end

  it 'CreatureTemplate.load_all can load the entire real directory without raising' do
    Lich::Gemstone::CreatureTemplate.class_variable_set(:@@templates, {})
    Lich::Gemstone::CreatureTemplate.class_variable_set(:@@loaded, false)

    expect { Lich::Gemstone::CreatureTemplate.load_all }.not_to raise_error
  end
end
