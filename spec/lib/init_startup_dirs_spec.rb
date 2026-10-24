# frozen_string_literal: true

require 'rspec'
require 'open3'
require 'json'
require 'rbconfig'

RSpec.describe 'init.rb startup directory error handling' do
  # init.rb runs top to bottom on load, so these specs pull the three real
  # rescue blocks out of the file and run each one in a child process with
  # Dir.mkdir/File.open failing for the target path and Lich.msgbox recorded.
  # Nothing is copied: a layout change that breaks extraction fails the spec.
  let(:harness) do
    <<~'RUBY'
      require 'json'
      init_path, kind, path, windows = ARGV
      LICH_DIR = path
      TEMP_DIR = path
      if windows == 'windows'
        module Win32
          def self.GetVersionEx = { dwMajorVersion: 10 }
          def self.isXP? = false
        end
      end
      module Lich
        MESSAGES = []
        def self.msgbox(args) = MESSAGES << args[:message]
      end
      error = ENV['MISSING_PARENT'] ? Errno::ENOENT : Errno::EACCES
      File.singleton_class.prepend(Module.new do
        define_method(:exist?) { |name| name == path ? false : !ENV['MISSING_PARENT'] }
        define_method(:open) { |name, *rest, &blk| name.start_with?(path) ? raise(error, name) : super(name, *rest, &blk) }
      end)
      Dir.singleton_class.prepend(Module.new do
        define_method(:mkdir) { |name, *| raise error, name }
      end)
      source = File.read(init_path)
      block = {
        'lich_dir' => source[/^unless File\.exist\?\(LICH_DIR\)\n.*?(?=^Dir\.chdir\(LICH_DIR\))/m],
        'temp_dir' => source[/^unless File\.exist\?\(TEMP_DIR\)\n.*?(?=^begin\n  debug_filename)/m],
        'debug_log' => source[/^begin\n  debug_filename.*?(?=^\$stderr\.sync)/m]
      }.fetch(kind) || abort("could not extract the #{kind} block from #{init_path}")
      exited = false
      begin
        Object.new.instance_eval { binding }.eval(block, init_path)
      rescue SystemExit
        exited = true
      end
      puts JSON.generate(exited: exited, messages: Lich::MESSAGES)
    RUBY
  end

  def run_block(kind, path, windows: true, missing_parent: false)
    stdout, stderr, status = Open3.capture3(
      { 'MISSING_PARENT' => (missing_parent ? '1' : nil) },
      RbConfig.ruby, '-e', harness,
      File.expand_path('../../lib/init.rb', __dir__), kind, path, windows ? 'windows' : 'posix'
    )
    expect(status.success?).to be(true), stderr
    JSON.parse(stdout.lines.last)
  end

  documents_hint = 'It is recommended to put Lich in your Documents folder.'

  %w[lich_dir temp_dir debug_log].each do |kind|
    describe "the #{kind} block" do
      [
        'C:/Users/me/Lich5',
        'C:\Users\me\Lich5',
        'c:/users/me/lich5',
        'C:\DOCUMENTS AND SETTINGS\me\Lich5'
      ].each do |path|
        it "shows the underlying error for a user-profile path #{path}" do
          result = run_block(kind, path)
          expect(result['exited']).to be(true)
          expect(result['messages'].size).to eq(1)
          expect(result['messages'].first).to include('Permission denied')
          expect(result['messages'].first).not_to include(documents_hint)
        end
      end

      ['C:/Games/Lich5', 'D:\Program Files\Lich5', 'C:/UsersShared/Lich5'].each do |path|
        it "suggests the Documents folder for a path outside the user profile #{path}" do
          result = run_block(kind, path)
          expect(result['exited']).to be(true)
          expect(result['messages']).to eq([result['messages'].first])
          expect(result['messages'].first).to include(documents_hint)
        end
      end

      it 'shows the underlying error when not on Windows' do
        result = run_block(kind, '/home/me/lich5', windows: false)
        expect(result['exited']).to be(true)
        expect(result['messages'].size).to eq(1)
        expect(result['messages'].first).to include('Permission denied')
      end
    end
  end

  %w[lich_dir temp_dir].each do |kind|
    it "the #{kind} block names a missing parent directory" do
      result = run_block(kind, 'C:/Missing/Lich5', missing_parent: true)
      expect(result['exited']).to be(true)
      expect(result['messages'].size).to eq(1)
      expect(result['messages'].first).to include("parent directory (C:/Missing) doesn't exist")
    end
  end
end
