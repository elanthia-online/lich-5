# frozen_string_literal: true

require 'tmpdir'
require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# What a `.name args` launch loads: ClassCommand_RunScript's ScriptName (FormMain.cs:
# 4682-4687 R) and AppendFile's exact lookup (Script.cs:3683-3800 R). The error texts and the
# lower-casing were recorded from the real Remix code (genieflow flow t162: `put .`, `put . x`,
# `put ..h`, `put .nosuch a b`, a prefix-only name, an `.inc`-only name, an empty file,
# `put .x.cmd`, `put .X`, `put .x.CMD`).
RSpec.describe Lich::Genie::ScriptLaunch do
  around do |example|
    Dir.mktmpdir('genie-launch') do |dir|
      @dir = dir
      example.run
    end
  end

  def write(name, text = "echo hi\n")
    path = File.join(@dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
    path
  end

  def error_of(file_name)
    described_class.resolve(@dir, file_name)
    nil
  rescue described_class::NotLoadable => e
    e.message
  end

  describe '.file_name / .script_name / .list_name' do
    it 'adds ".cmd" unless the (lower-cased) name already ends with it, so `put .x.cmd` loads x.cmd' do
      expect(%w[hunt hunt.cmd hunt.cmd.cmd .h x.CMD].map { |n| described_class.file_name(n) })
        .to eq(%w[hunt.cmd hunt.cmd hunt.cmd.cmd .h.cmd x.CMD.cmd])
    end

    it 'gives ".cmd" for an empty name (`put .`, `put . x`)' do
      expect(described_class.file_name('')).to eq('.cmd')
    end

    it 'derives %scriptname by dropping a trailing ".cmd" (case-insensitive test), else keeps the file name' do
      expect(%w[hunt.cmd a.b.cmd .cmd X.CMD noext].map { |f| described_class.script_name(f) })
        .to eq(['hunt', 'a.b', '', 'X', 'noext'])
    end

    it 'derives the $scriptlist name like GetFileNameWithoutExtension (last separator, last dot)' do
      expect(['hunt.cmd', 'a.b.cmd', '.cmd', 'sub/x.cmd', 'sub\\y.cmd', 'noext', 'trail.'].map { |f| described_class.list_name(f) })
        .to eq(['hunt', 'a.b', '', 'x', 'y', 'noext', 'trail'])
    end
  end

  describe '.request' do
    it 'parses the arguments like the launch tokenizer and keeps the file name' do
      request = described_class.request('hunt', '"two words" c_d')
      expect([request.file_name, request.args, request.script_name]).to eq(['hunt.cmd', ['two words', 'c d'], 'hunt'])
    end

    it 'takes an Array of arguments and no arguments at all' do
      expect(described_class.request('x.cmd', %w[a b]).args).to eq(%w[a b])
      expect(described_class.request('x', '').args).to eq([])
    end

    it 'raises ParseArgs\' error for a malformed argument string before anything is resolved' do
      expect { described_class.request('hunt', 'a "') }.to raise_error(Lich::Genie::Error, 'Invalid string in Parse Arguments: .hunt a "')
    end
  end

  describe '.resolve' do
    it 'returns exactly <dir>/<file>' do
      path = write('hunt.cmd')
      expect(described_class.resolve(@dir, 'hunt.cmd')).to eq(path)
    end

    it 'never prefix-matches, never tries another extension, a .gz or a custom/ layer (Lich finder supersets)' do
      write('hunter.cmd')
      write('hunt.lic')
      write('hunt.inc')
      write('hunt.cmd.gz')
      write('custom/hunt.cmd')
      expect(error_of('hunt.cmd')).to eq('File not found: hunt.cmd')
    end

    # macOS finds it through its case-insensitive file system, Linux through the directory scan.
    it 'finds a file whose name differs only in case (Remix runs on a case-insensitive file system)' do
      write('Hunt.CMD')
      found = described_class.resolve(@dir, 'hunt.cmd')
      expect([File.basename(found).downcase, File.file?(found)]).to eq(['hunt.cmd', true])
    end

    it 'reports a missing file, a directory and the empty name as "File not found"' do
      FileUtils.mkdir_p(File.join(@dir, 'adir.cmd'))
      expect([error_of('nosuch.cmd'), error_of('adir.cmd'), error_of('.cmd'), error_of('.h.cmd')])
        .to eq(['File not found: nosuch.cmd', 'File not found: adir.cmd', 'File not found: .cmd', 'File not found: .h.cmd'])
    end

    it 'reports an empty file as "Unable to load file" (fi.Length > 0 fails)' do
      write('empty.cmd', '')
      expect(error_of('empty.cmd')).to eq('Unable to load file: empty.cmd')
    end

    it 'resolves a name with a path part under the script dir, a backslash taken as a separator' do
      path = write('sub/deep.cmd')
      expect([described_class.resolve(@dir, 'sub/deep.cmd'), described_class.resolve(@dir, 'sub\\deep.cmd')]).to eq([path, path])
    end

    it 'reports a missing parent directory as "File not found" without raising anything else' do
      expect(error_of('nowhere/x.cmd')).to eq('File not found: nowhere/x.cmd')
    end
  end
end
